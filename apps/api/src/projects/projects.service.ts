import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository, SelectQueryBuilder } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Site } from '../customers/entities/site.entity';
import { Project } from './entities/project.entity';
import { ProjectAssignment } from './entities/project-assignment.entity';
import { AssignCrewDto, CreateProjectDto, UpdateProjectDto } from './dto/project.dto';

@Injectable()
export class ProjectsService {
  constructor(
    @InjectRepository(Project) private readonly projects: Repository<Project>,
    @InjectRepository(ProjectAssignment) private readonly assignments: Repository<ProjectAssignment>,
    @InjectRepository(Site) private readonly sites: Repository<Site>,
  ) {}

  /**
   * El WORKER solo ve donde tiene asignación: directa, o por la cuadrilla a la
   * que pertenecía en esa fecha. RLS aísla entre empresas; esto acota adentro,
   * para que un trabajador no enumere todos los clientes y direcciones.
   */
  list(tenant?: TenantContext): Promise<Project[]> {
    const q = this.projects.createQueryBuilder('p')
      .leftJoinAndSelect('p.customer', 'customer')
      .leftJoinAndSelect('p.site', 'site')
      .where('p.deletedAt IS NULL')
      .orderBy('p.createdAt', 'DESC');

    if (tenant?.role === 'WORKER') this.restrictToAssigned(q, tenant.membershipId);
    return q.getMany();
  }

  async get(id: string, tenant?: TenantContext): Promise<Project> {
    const q = this.projects.createQueryBuilder('p')
      .leftJoinAndSelect('p.customer', 'customer')
      .leftJoinAndSelect('p.site', 'site')
      .where('p.id = :id', { id })
      .andWhere('p.deletedAt IS NULL');

    if (tenant?.role === 'WORKER') this.restrictToAssigned(q, tenant.membershipId);

    const found = await q.getOne();
    // Mismo 404 que si no existiera: no se confirma la existencia de un proyecto
    // al que no se tiene acceso.
    if (!found) throw ApiError.notFound('NOT_FOUND', 'Proyecto no encontrado');
    return found;
  }

  private restrictToAssigned(q: SelectQueryBuilder<Project>, membershipId: string): void {
    q.andWhere(
      `EXISTS (
         SELECT 1 FROM project_assignment a
         LEFT JOIN crew_member cm
           ON cm.crew_id = a.crew_id
          AND cm.deleted_at IS NULL
          AND a.work_date BETWEEN cm.from_date AND coalesce(cm.to_date, a.work_date)
         WHERE a.project_id = p.id
           AND a.deleted_at IS NULL
           AND (a.membership_id = :mid OR cm.membership_id = :mid)
       )`,
      { mid: membershipId },
    );
  }

  @Transactional()
  async create(dto: CreateProjectDto, tenant: TenantContext): Promise<Project> {
    const id = dto.id ?? newId();
    if (dto.id && (await this.projects.findOne({ where: { id } }))) {
      throw new ConflictException('Ya existe un proyecto con ese id');
    }
    // El sitio tiene que ser del mismo cliente: no se cruzan.
    const site = await this.sites.findOne({ where: { id: dto.siteId, deletedAt: IsNull() } });
    if (!site) throw new NotFoundException('Sitio no encontrado');
    if (site.customerId !== dto.customerId) {
      throw new BadRequestException('El sitio no pertenece a ese cliente');
    }

    const project = this.projects.create({
      id,
      companyId: tenant.companyId,
      customer: { id: dto.customerId } as Project['customer'],
      site: { id: dto.siteId } as Project['site'],
      name: dto.name,
      description: dto.description ?? null,
      serviceType: dto.serviceType ?? null,
      status: dto.status ?? 'LEAD',
      clientVisibilityMode: dto.clientVisibilityMode ?? 'STAGES',
      startDate: dto.startDate ?? null,
      targetEndDate: dto.targetEndDate ?? null,
      actualEndDate: null,
      publishedAt: null,
      deletedAt: null,
    });
    await this.projects.save(project);
    return this.get(id);
  }

  async update(id: string, dto: UpdateProjectDto): Promise<Project> {
    await this.get(id);
    await this.projects.update({ id }, dto);
    return this.get(id);
  }

  async remove(id: string): Promise<void> {
    await this.get(id);
    await this.projects.update({ id }, { deletedAt: new Date() });
  }

  async assign(projectId: string, dto: AssignCrewDto, tenant: TenantContext): Promise<ProjectAssignment> {
    await this.get(projectId);
    if (!dto.crewId === !dto.membershipId) {
      throw new BadRequestException('Indicar cuadrilla o persona, no ambas');
    }
    const assignment = this.assignments.create({
      id: newId(),
      companyId: tenant.companyId,
      project: { id: projectId } as ProjectAssignment['project'],
      crew: dto.crewId ? ({ id: dto.crewId } as ProjectAssignment['crew']) : null,
      membership: dto.membershipId ? ({ id: dto.membershipId } as ProjectAssignment['membership']) : null,
      workDate: dto.workDate,
      plannedHeadcount: dto.plannedHeadcount ?? null,
      deletedAt: null,
    });
    return this.assignments.save(assignment);
  }

  listAssignments(projectId: string): Promise<ProjectAssignment[]> {
    return this.assignments.find({
      where: { project: { id: projectId }, deletedAt: IsNull() },
      relations: { crew: true, membership: true },
      order: { workDate: 'ASC' },
    });
  }
}
