import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, IsNull, Not, Repository } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { randomInt } from 'node:crypto';
import * as bcrypt from 'bcryptjs';
import { ApiError } from '../common/errors/api-error';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { AppUser } from '../auth/entities/app-user.entity';
import { Membership, MembershipRole } from '../auth/entities/membership.entity';
import { CrewMember } from '../crews/entities/crew-member.entity';
import { normalizeIdentifier } from '../auth/phone';
import { CreateMemberDto, MemberDto, MemberWithInviteDto, UpdateMemberDto } from './dto/membership.dto';

const INVITE_TTL_DAYS = 7;

/** Seis dígitos, cero incluido: "048291" es un código válido y se dicta igual. */
function newInviteCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

@Injectable()
export class MembershipsService {
  constructor(
    @InjectRepository(Membership) private readonly memberships: Repository<Membership>,
    @InjectRepository(AppUser) private readonly users: Repository<AppUser>,
    @InjectRepository(CrewMember) private readonly crewMembers: Repository<CrewMember>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async list(): Promise<MemberDto[]> {
    const rows = await this.memberships.find({
      where: { deletedAt: IsNull() },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });
    return this.toDtos(rows);
  }

  async get(id: string): Promise<MemberDto> {
    const [dto] = await this.toDtos([await this.entity(id)]);
    return dto;
  }

  @Transactional()
  async create(dto: CreateMemberDto, tenant: TenantContext): Promise<MemberWithInviteDto> {
    const { email, phone } = this.contactOf(dto);
    await this.assertSingleOwner(dto.role);
    const user = await this.upsertUser(dto, email, phone);

    const existing = await this.memberships.findOne({
      where: { user: { id: user.id }, deletedAt: IsNull() },
    });
    if (existing && existing.status !== 'INACTIVE') {
      throw ApiError.conflict('CONTACT_ALREADY_MEMBER', 'Esa persona ya es parte de la empresa');
    }

    // Volver de temporada reactiva la misma fila: sus horas y su pertenencia
    // terminada a una cuadrilla siguen apuntando a esta membresía.
    const id = existing?.id ?? dto.id ?? newId();
    if (!existing) {
      await this.memberships.insert({
        id,
        companyId: tenant.companyId,
        user: { id: user.id } as Membership['user'],
        role: dto.role,
        payRateCents: dto.payRateCents ?? null,
        employmentType: dto.employmentType ?? null,
        status: 'INVITED',
        deletedAt: null,
      });
    } else {
      await this.memberships.update({ id }, {
        role: dto.role,
        payRateCents: dto.payRateCents ?? null,
        employmentType: dto.employmentType ?? null,
      });
    }

    return this.emitInvite(id);
  }

  @Transactional()
  async update(id: string, dto: UpdateMemberDto): Promise<MemberDto> {
    const membership = await this.entity(id);
    if (dto.role) await this.assertSingleOwner(dto.role, id);

    await this.memberships.update({ id }, {
      ...(dto.role !== undefined ? { role: dto.role } : {}),
      ...(dto.payRateCents !== undefined ? { payRateCents: dto.payRateCents } : {}),
      ...(dto.employmentType !== undefined ? { employmentType: dto.employmentType } : {}),
    });

    await this.updateUser(membership.userId, dto);
    return this.get(id);
  }

  /**
   * El nombre y el contacto viven en `app_user`, así que corregirlos alcanza a
   * todas las empresas donde esa persona trabaje. Es correcto: es la misma
   * persona y el dato estaba mal en las dos.
   */
  private async updateUser(userId: string, dto: UpdateMemberDto): Promise<void> {
    const cambios: Partial<AppUser> = {};
    if (dto.name !== undefined) cambios.name = dto.name;
    if (dto.email !== undefined) cambios.email = dto.email ? normalizeIdentifier(dto.email).email : null;
    if (dto.phone !== undefined) cambios.phone = dto.phone ? normalizeIdentifier(dto.phone).phone : null;
    if (!Object.keys(cambios).length) return;

    // Se compara contra lo que **queda** en la fila, no contra lo que vino en el
    // cuerpo: mandar solo `{phone: null}` sobre alguien sin correo lo dejaba sin
    // forma de entrar, y el guard no disparaba porque miraba las dos claves.
    const actual = await this.users.findOneOrFail({ where: { id: userId } });
    const quedan = {
      email: 'email' in cambios ? cambios.email : actual.email,
      phone: 'phone' in cambios ? cambios.phone : actual.phone,
    };
    if (!quedan.email && !quedan.phone) {
      throw ApiError.badRequest('VALIDATION_FAILED', 'Hace falta un correo o un teléfono');
    }

    // El correo y el teléfono son únicos globales: si ya son de otra persona, el
    // rechazo llega con el mismo código que el del alta.
    const ocupado = await this.users.findOne({
      where: [
        ...(cambios.email ? [{ email: cambios.email, deletedAt: IsNull() }] : []),
        ...(cambios.phone ? [{ phone: cambios.phone, deletedAt: IsNull() }] : []),
      ],
    });
    if (ocupado && ocupado.id !== userId) {
      throw ApiError.conflict('CONTACT_ALREADY_MEMBER', 'Ese correo o teléfono ya es de otra persona');
    }

    await this.users.update({ id: userId }, cambios);
  }

  /**
   * Emite un código nuevo, e invalida el anterior. Es también el camino de la
   * contraseña olvidada: un trabajador sin correo no tiene por dónde recibir un
   * link, así que vuelve a `INVITED` y elige contraseña de nuevo al canjear.
   */
  @Transactional()
  async regenerateInvite(id: string): Promise<MemberWithInviteDto> {
    const membership = await this.entity(id);

    // Sube token_version: quien esté adentro con esta membresía queda afuera, que
    // es lo correcto —quien perdió el acceso no tiene sesión viva— y es la razón
    // de que el panel lo pida nombrando a la persona.
    await this.memberships.increment({ id }, 'tokenVersion', 1);

    if (await this.isOnlyActiveMembership(membership.userId, id)) {
      await this.users.update({ id: membership.userId }, { passwordHash: null });
    }
    return this.emitInvite(id);
  }

  @Transactional()
  async deactivate(id: string): Promise<MemberDto> {
    await this.entity(id);
    await this.memberships.update({ id }, {
      status: 'INACTIVE',
      inviteCodeHash: null,
      inviteExpiresAt: null,
    });
    await this.memberships.increment({ id }, 'tokenVersion', 1);
    return this.get(id);
  }

  private async emitInvite(id: string): Promise<MemberWithInviteDto> {
    const code = newInviteCode();
    const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000);

    await this.memberships.update({ id }, {
      status: 'INVITED',
      invitedAt: new Date(),
      joinedAt: null,
      inviteCodeHash: await bcrypt.hash(code, 12),
      inviteExpiresAt: expiresAt,
      // Sin esto, una persona bloqueada por intentos queda bloqueada para siempre.
      inviteAttempts: 0,
    });

    return { ...(await this.get(id)), inviteCode: code };
  }

  /**
   * Cruza tenants a propósito (regla 6): la contraseña es del usuario, no de la
   * membresía, y nulearla acá dejaría sin entrar a la empresa donde sí trabaja.
   * Reusa la función del login en vez de una `SECURITY DEFINER` nueva.
   */
  private async isOnlyActiveMembership(userId: string, exceptId: string): Promise<boolean> {
    const rows = await this.dataSource.query<{ id: string }[]>(
      `SELECT m.id FROM auth_memberships_for_user($1) m WHERE m.id <> $2`,
      [userId, exceptId],
    );
    return rows.length === 0;
  }

  /**
   * `uq_membership_single_owner` solo cubre el OWNER **activo**, y una membresía
   * nace `INVITED`: sin esto, el segundo dueño se crea sin ruido y el choque
   * aparece recién al canjear, en la cara del trabajador y no de quien lo dio de
   * alta.
   */
  private async assertSingleOwner(role: MembershipRole, exceptId?: string): Promise<void> {
    if (role !== 'OWNER') return;
    const otro = await this.memberships.findOne({
      where: { role: 'OWNER', status: Not('INACTIVE'), deletedAt: IsNull() },
    });
    if (otro && otro.id !== exceptId) {
      throw ApiError.conflict('OWNER_ALREADY_EXISTS', 'La empresa ya tiene un dueño');
    }
  }

  private contactOf(dto: CreateMemberDto): { email: string | null; phone: string | null } {
    const email = dto.email ? normalizeIdentifier(dto.email).email : null;
    const phone = dto.phone ? normalizeIdentifier(dto.phone).phone : null;
    if (!email && !phone) {
      throw ApiError.badRequest('VALIDATION_FAILED', 'Hace falta un correo o un teléfono');
    }
    return { email, phone };
  }

  /** Una persona puede trabajar para dos contratistas: un `user`, dos membresías. */
  private async upsertUser(dto: CreateMemberDto, email: string | null, phone: string | null): Promise<AppUser> {
    const found = await this.users.findOne({
      where: [
        ...(email ? [{ email, deletedAt: IsNull() }] : []),
        ...(phone ? [{ phone, deletedAt: IsNull() }] : []),
      ],
    });
    if (found) return found;

    const user = this.users.create({
      id: newId(),
      name: dto.name,
      email,
      phone,
      // La elige al canjear. Nula hasta entonces, y sin contraseña no hay login.
      passwordHash: null,
      locale: dto.locale ?? 'en',
      deletedAt: null,
    });
    return this.users.save(user);
  }

  private async entity(id: string): Promise<Membership> {
    const found = await this.memberships.findOne({
      where: { id, deletedAt: IsNull() },
      relations: { user: true },
    });
    if (!found) throw new NotFoundException('Persona no encontrada');
    return found;
  }

  private async toDtos(rows: Membership[]): Promise<MemberDto[]> {
    if (!rows.length) return [];

    // pay_rate_cents y las columnas de invitación van con select: false, así que
    // no vienen en `rows`: se piden explícito, y solo por este camino.
    const hidden = await this.memberships
      .createQueryBuilder('m')
      .select(['m.id'])
      .addSelect(['m.payRateCents', 'm.inviteExpiresAt'])
      .where('m.id IN (:...ids)', { ids: rows.map((r) => r.id) })
      .getMany();
    const byId = new Map(hidden.map((m) => [m.id, m]));

    // La cuadrilla vigente hoy, no la última: la pertenencia lleva fechas y una
    // persona puede tener tramos cerrados en varias.
    const today = new Date().toISOString().slice(0, 10);
    const crews = await this.crewMembers.find({
      where: { membership: { id: In(rows.map((r) => r.id)) }, deletedAt: IsNull() },
      relations: { crew: true },
    });
    const crewOf = new Map(
      crews
        .filter((cm) => cm.fromDate <= today && (cm.toDate === null || cm.toDate >= today))
        .map((cm) => [cm.membershipId, { id: cm.crewId, name: cm.crew.name }]),
    );

    return rows.map((m) => ({
      id: m.id,
      userId: m.userId,
      name: m.user.name,
      email: m.user.email,
      phone: m.user.phone,
      locale: m.user.locale,
      role: m.role,
      status: m.status,
      payRateCents: byId.get(m.id)?.payRateCents ?? null,
      employmentType: m.employmentType,
      invitedAt: m.invitedAt,
      joinedAt: m.joinedAt,
      inviteExpiresAt: byId.get(m.id)?.inviteExpiresAt ?? null,
      crew: crewOf.get(m.id) ?? null,
    }));
  }
}
