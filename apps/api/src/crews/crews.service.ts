import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, QueryFailedError, Repository, SelectQueryBuilder } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Crew } from './entities/crew.entity';
import { CrewMember } from './entities/crew-member.entity';
import { ProjectAssignment } from '../projects/entities/project-assignment.entity';
import {
  AddCrewMemberDto, CreateCrewDto, CrewAssignmentDto, CrewDto, CrewMemberDto, UpdateCrewDto,
} from './dto/crew.dto';

@Injectable()
export class CrewsService {
  constructor(
    @InjectRepository(Crew) private readonly crews: Repository<Crew>,
    @InjectRepository(CrewMember) private readonly members: Repository<CrewMember>,
    @InjectRepository(ProjectAssignment) private readonly assignments: Repository<ProjectAssignment>,
  ) {}

  /**
   * Devuelve DTO y no la entity: la cuadrilla se lee con `crews.read`, que
   * incluye al FOREMAN, y la membresía embebida arrastraría el contacto de la
   * persona. Cierra la mitad de DEBT-0010 que corresponde a `/crews`.
   */
  async list(tenant: TenantContext): Promise<CrewDto[]> {
    const crews = await this.suyas(tenant).getMany();
    const counts = await this.memberCounts(crews.map((c) => c.id));
    return crews.map((c) => this.toDto(c, counts.get(c.id) ?? 0));
  }

  async get(id: string, tenant: TenantContext): Promise<CrewDto> {
    const crew = await this.entity(id, tenant);
    const counts = await this.memberCounts([id]);
    return this.toDto(crew, counts.get(id) ?? 0);
  }

  /**
   * El capataz ve la cuadrilla que lidera o que integra hoy, y ninguna otra;
   * quien administra las ve todas.
   *
   * **Es la misma regla que el pull** (`cuadrillaVisible` en `sync.service.ts`),
   * y tiene que serlo: el espejo local del teléfono ya venía acotado, así que
   * dejar el REST abierto hacía que la app mostrara una cosa u otra según de
   * dónde leyera. El scope por rol **es** el control de acceso acá, porque
   * `crews.read` incluye al FOREMAN.
   */
  private suyas(tenant: TenantContext): SelectQueryBuilder<Crew> {
    const q = this.crews.createQueryBuilder('crew')
      .leftJoinAndSelect('crew.foreman', 'foreman')
      .leftJoinAndSelect('foreman.user', 'foremanUser')
      .where('crew.deleted_at IS NULL');

    if (tenant.role !== 'FOREMAN') return q;
    return q.andWhere(
      `(crew.foreman_membership_id = :suyo
        OR EXISTS (SELECT 1 FROM crew_member cmx
                     WHERE cmx.crew_id = crew.id AND cmx.membership_id = :suyo
                       AND cmx.deleted_at IS NULL
                       AND CURRENT_DATE BETWEEN cmx.from_date
                         AND coalesce(cmx.to_date, CURRENT_DATE)))`,
      { suyo: tenant.membershipId },
    );
  }

  /**
   * La ajena responde 404 y no 403: que exista es lo que no le toca saber.
   */
  private async entity(id: string, tenant: TenantContext): Promise<Crew> {
    const found = await this.suyas(tenant).andWhere('crew.id = :id', { id }).getOne();
    if (!found) throw new NotFoundException('Cuadrilla no encontrada');
    return found;
  }

  async create(dto: CreateCrewDto, tenant: TenantContext): Promise<CrewDto> {
    const crew = this.crews.create({
      id: dto.id ?? newId(),
      companyId: tenant.companyId,
      name: dto.name,
      foreman: dto.foremanMembershipId ? ({ id: dto.foremanMembershipId } as Crew['foreman']) : null,
      color: dto.color ?? null,
      deletedAt: null,
    });
    await this.crews.save(crew);
    return this.get(crew.id, tenant);
  }

  async update(id: string, dto: UpdateCrewDto, tenant: TenantContext): Promise<CrewDto> {
    await this.entity(id, tenant);
    const { foremanMembershipId, ...rest } = dto;
    await this.crews.update({ id }, {
      ...rest,
      ...(foremanMembershipId ? { foreman: { id: foremanMembershipId } } : {}),
    });
    return this.get(id, tenant);
  }

  async listMembers(crewId: string, tenant: TenantContext): Promise<CrewMemberDto[]> {
    await this.entity(crewId, tenant);
    const rows = await this.members.find({
      where: { crew: { id: crewId }, deletedAt: IsNull() },
      relations: { membership: { user: true } },
      order: { fromDate: 'DESC' },
    });
    return rows.map((cm) => ({
      id: cm.id,
      membershipId: cm.membershipId,
      name: cm.membership.user.name,
      role: cm.membership.role,
      fromDate: cm.fromDate,
      toDate: cm.toDate,
    }));
  }

  /** Las asignaciones de la cuadrilla, para no pedirlas obra por obra. */
  async listAssignments(crewId: string, tenant: TenantContext): Promise<CrewAssignmentDto[]> {
    await this.entity(crewId, tenant);
    const rows = await this.assignments.find({
      where: { crew: { id: crewId }, deletedAt: IsNull() },
      relations: { project: true },
      order: { fromDate: 'ASC' },
    });
    return rows.map((a) => ({
      id: a.id,
      projectId: a.projectId,
      projectName: a.project.name,
      fromDate: a.fromDate,
      toDate: a.toDate,
    }));
  }

  /**
   * Cuál es la cuadrilla que choca. El rechazo lo produce la base, que no sabe
   * de nombres: se resuelve acá para que el mensaje diga a dónde ir en vez de
   * mandar a buscarla a mano.
   *
   * **Se pregunta antes de insertar, nunca en el `catch`.** El request corre
   * dentro de una transacción y, cuando la exclusión salta, Postgres la aborta
   * entera: cualquier consulta posterior falla y se lleva puesto el error bueno.
   */
  private async cuadrillaQueChoca(
    membershipId: string, fromDate: string, toDate: string | null,
  ): Promise<string | null> {
    const filas = await this.members.query<{ name: string }[]>(
      `SELECT c.name
       FROM crew_member cm
       JOIN crew c ON c.id = cm.crew_id
       WHERE cm.membership_id = $1
         AND cm.deleted_at IS NULL
         AND daterange(cm.from_date, cm.to_date, '[]') && daterange($2::date, $3::date, '[]')
       LIMIT 1`,
      [membershipId, fromDate, toDate],
    );
    return filas[0]?.name ?? null;
  }

  private toDto(crew: Crew, memberCount: number): CrewDto {
    return {
      id: crew.id,
      name: crew.name,
      color: crew.color,
      foreman: crew.foreman
        ? { membershipId: crew.foreman.id, name: crew.foreman.user.name }
        : null,
      memberCount,
    };
  }

  private async memberCounts(crewIds: string[]): Promise<Map<string, number>> {
    if (!crewIds.length) return new Map();
    const today = new Date().toISOString().slice(0, 10);
    const rows = await this.members.find({
      where: { crew: { id: In(crewIds) }, deletedAt: IsNull() },
    });
    const counts = new Map<string, number>();
    for (const cm of rows) {
      // Vigentes hoy: la pertenencia lleva fechas y los tramos cerrados no cuentan.
      if (cm.fromDate <= today && (cm.toDate === null || cm.toDate >= today)) {
        counts.set(cm.crewId, (counts.get(cm.crewId) ?? 0) + 1);
      }
    }
    return counts;
  }

  @Transactional()
  async addMember(crewId: string, dto: AddCrewMemberDto, tenant: TenantContext): Promise<CrewMember> {
    await this.entity(crewId, tenant);
    if (dto.toDate && dto.toDate < dto.fromDate) {
      throw new BadRequestException('La fecha de salida no puede ser anterior a la de entrada');
    }
    const otra = await this.cuadrillaQueChoca(dto.membershipId, dto.fromDate, dto.toDate ?? null);
    if (otra) throw this.solape(otra);

    const member = this.members.create({
      id: newId(),
      companyId: tenant.companyId,
      crew: { id: crewId } as CrewMember['crew'],
      membership: { id: dto.membershipId } as CrewMember['membership'],
      fromDate: dto.fromDate,
      toDate: dto.toDate ?? null,
      deletedAt: null,
    });
    try {
      return await this.members.save(member);
    } catch (e) {
      // La exclusión sigue siendo la que manda: dos altas simultáneas pasan el
      // chequeo de arriba y una tiene que perder. Sin nombre, porque a esta
      // altura la transacción ya está abortada.
      if (e instanceof QueryFailedError && String(e.message).includes('crew_member_no_overlap')) {
        throw this.solape(null);
      }
      throw e;
    }
  }

  /**
   * El nombre viaja en `details` y no dentro del mensaje (ADR-0011): el panel
   * arma la frase en el idioma de quien mira, que no es el del servidor.
   */
  private solape(otra: string | null): ApiError {
    return ApiError.conflict(
      'CREW_MEMBER_OVERLAP',
      otra
        ? `Esa persona ya pertenece a ${otra} en ese rango de fechas`
        : 'Esa persona ya pertenece a una cuadrilla en ese rango de fechas',
      otra ? [{ field: 'crew', message: otra }] : [],
    );
  }

  async endMembership(
    crewId: string, memberId: string, toDate: string, tenant: TenantContext,
  ): Promise<CrewMember> {
    await this.entity(crewId, tenant);
    const member = await this.members.findOne({ where: { id: memberId, crew: { id: crewId } } });
    if (!member) throw new NotFoundException('Miembro no encontrado');
    await this.members.update({ id: memberId }, { toDate });
    return (await this.members.findOne({ where: { id: memberId } }))!;
  }
}
