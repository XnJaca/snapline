import { ApiError } from '../common/errors/api-error';
import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Membership } from '../auth/entities/membership.entity';
import { Project } from '../projects/entities/project.entity';
import { TimeEntry, TIME_ENTRY_FLAGS } from './entities/time-entry.entity';
import { TimeEntryEdit } from './entities/time-entry-edit.entity';
import { ApproveDto, ClockInDto, ClockOutDto } from './dto/time-entry.dto';
import { distanceMeters } from './geo';

const DEFAULT_GEOFENCE_M = 150;
const MAX_SHIFT_HOURS = 14;
const MAX_BACKDATE_DAYS = 7;

@Injectable()
export class TimeEntriesService {
  constructor(
    @InjectRepository(TimeEntry) private readonly entries: Repository<TimeEntry>,
    @InjectRepository(TimeEntryEdit) private readonly edits: Repository<TimeEntryEdit>,
    @InjectRepository(Project) private readonly projects: Repository<Project>,
    @InjectRepository(Membership) private readonly memberships: Repository<Membership>,
  ) {}

  @Transactional()
  async clockIn(dto: ClockInDto, tenant: TenantContext): Promise<TimeEntry> {
    const project = await this.projects.findOne({
      where: { id: dto.projectId, deletedAt: IsNull() },
      relations: { site: true },
    });
    if (!project) throw new NotFoundException('Proyecto no encontrado');

    const targetMembershipId = dto.membershipId ?? tenant.membershipId;
    if (targetMembershipId !== tenant.membershipId) {
      await this.assertCanRecordForOthers(tenant);
    }

    const open = await this.entries.findOne({
      where: { membership: { id: targetMembershipId }, clockOutAt: IsNull(), deletedAt: IsNull() },
    });
    if (open) throw ApiError.conflict('TIME_ENTRY_ALREADY_OPEN', 'Ya hay un registro abierto para esa persona');

    const { deviceRecordedAt, flags: timeFlags } = this.boundDeviceTime(dto.deviceRecordedAt);
    const geo = this.evaluateGeofence(project, dto.lat, dto.lng);

    const flags = [...timeFlags, ...geo.flags];
    if (!dto.photoId) flags.push(TIME_ENTRY_FLAGS.NO_PHOTO);
    if (dto.isMockLocation) flags.push(TIME_ENTRY_FLAGS.MOCK_LOCATION);

    // El criterio para que un foreman marque por otro es la obra, no la
    // cuadrilla, y es bandera y no bloqueo: una asignación sin cargar no puede
    // dejar a nadie sin fichar (regla 9). OWNER y ADMIN quedan sin acotar.
    if (targetMembershipId !== tenant.membershipId && tenant.role === 'FOREMAN') {
      const asignado = await this.recorderAssignedThatDay(
        tenant.membershipId, project.id, deviceRecordedAt,
      );
      if (!asignado) flags.push(TIME_ENTRY_FLAGS.RECORDER_NOT_ASSIGNED);
    }

    const entry = this.entries.create({
      id: dto.id ?? newId(),
      companyId: tenant.companyId,
      project: { id: project.id } as TimeEntry['project'],
      membership: { id: targetMembershipId } as TimeEntry['membership'],
      recordedBy: { id: tenant.membershipId } as TimeEntry['recordedBy'],
      clockInAt: deviceRecordedAt,
      clockOutAt: null,
      breakMinutes: 0,
      clockInLat: dto.lat ?? null,
      clockInLng: dto.lng ?? null,
      clockInAccuracyM: dto.accuracyM ?? null,
      clockInDistanceM: geo.distanceM,
      clockInWithinGeofence: geo.within,
      clockInPhotoId: dto.photoId ?? null,
      // Del rol de quien marca, no de por quién: "lo marcó un foreman" cuando
      // lo marcó el dueño es un dato falso en el rastro de la regla 12.
      method: this.methodFor(tenant, targetMembershipId),
      deviceId: dto.deviceId ?? null,
      isMockLocation: dto.isMockLocation ?? false,
      recordedOffline: dto.recordedOffline ?? false,
      deviceRecordedAt,
      serverReceivedAt: new Date(),
      status: 'PENDING',
      payRateCentsSnapshot: null,
      approvedBy: null,
      approvedAt: null,
      flags,
      deletedAt: null,
    });
    return this.entries.save(entry);
  }

  @Transactional()
  async clockOut(id: string, dto: ClockOutDto, tenant: TenantContext): Promise<TimeEntry> {
    const entry = await this.get(id);
    if (entry.clockOutAt) throw ApiError.conflict('TIME_ENTRY_ALREADY_CLOSED', 'El registro ya fue cerrado');
    if (entry.membershipId !== tenant.membershipId) {
      await this.assertCanRecordForOthers(tenant);
    }

    const project = await this.projects.findOne({
      where: { id: entry.projectId }, relations: { site: true },
    });
    const { deviceRecordedAt, flags: timeFlags } = this.boundDeviceTime(dto.deviceRecordedAt);
    if (deviceRecordedAt <= entry.clockInAt) {
      throw new BadRequestException('La salida no puede ser anterior a la entrada');
    }

    const geo = project ? this.evaluateGeofence(project, dto.lat, dto.lng) : { distanceM: null, within: null, flags: [] };
    const flags = new Set([...entry.flags, ...timeFlags, ...geo.flags]);
    if (dto.isMockLocation) flags.add(TIME_ENTRY_FLAGS.MOCK_LOCATION);

    // La misma evaluación que al entrar: cerrar la jornada de otro sin haber
    // estado asignado a esa obra ese día también se marca, no solo abrirla.
    if (entry.membershipId !== tenant.membershipId && tenant.role === 'FOREMAN') {
      const asignado = await this.recorderAssignedThatDay(
        tenant.membershipId, entry.projectId, deviceRecordedAt,
      );
      if (!asignado) flags.add(TIME_ENTRY_FLAGS.RECORDER_NOT_ASSIGNED);
    }

    const hours = (deviceRecordedAt.getTime() - entry.clockInAt.getTime()) / 3_600_000;
    if (hours > MAX_SHIFT_HOURS) flags.add(TIME_ENTRY_FLAGS.SHIFT_TOO_LONG);

    await this.entries.update({ id }, {
      clockOutAt: deviceRecordedAt,
      clockOutLat: dto.lat ?? null,
      clockOutLng: dto.lng ?? null,
      clockOutAccuracyM: dto.accuracyM ?? null,
      clockOutDistanceM: geo.distanceM,
      clockOutWithinGeofence: geo.within,
      clockOutPhotoId: dto.photoId ?? null,
      breakMinutes: dto.breakMinutes ?? 0,
      flags: [...flags],
    });
    return this.get(id);
  }

  @Transactional()
  async approve(id: string, dto: ApproveDto, tenant: TenantContext): Promise<TimeEntry> {
    const entry = await this.get(id);
    this.assertDecidable(entry, 'APPROVED', dto, tenant);
    if (!entry.clockOutAt) {
      throw ApiError.badRequest('TIME_ENTRY_STILL_OPEN', 'El registro sigue abierto');
    }

    // La tarifa va con `select: false` en la entity: acá se pide explícito,
    // porque aprobar es el momento que la congela (regla 13).
    const membership = await this.memberships.findOne({
      where: { id: entry.membershipId },
      select: { id: true, payRateCents: true },
    });
    if (!membership?.payRateCents) {
      throw ApiError.badRequest('PAY_RATE_MISSING', 'La persona no tiene tarifa definida');
    }

    await this.applyDecision(entry, 'APPROVED', dto, tenant, membership.payRateCents);
    return this.get(id);
  }

  @Transactional()
  async reject(id: string, dto: ApproveDto, tenant: TenantContext): Promise<TimeEntry> {
    const entry = await this.get(id);
    this.assertDecidable(entry, 'REJECTED', dto, tenant);
    await this.applyDecision(entry, 'REJECTED', dto, tenant, null);
    return this.get(id);
  }

  /// Lo que se puede saber antes de escribir: de quién son las horas, y si la
  /// decisión llega sobre el estado que quien decidió tenía a la vista.
  private assertDecidable(
    entry: TimeEntry, destino: TimeEntry['status'], dto: ApproveDto, tenant: TenantContext,
  ): void {
    // Nadie decide sobre sus propias horas, ni siquiera un OWNER.
    if (entry.membershipId === tenant.membershipId) {
      throw ApiError.forbidden('CANNOT_APPROVE_OWN_HOURS', 'No se puede decidir sobre las horas propias');
    }
    // Alguien ya decidió lo mismo desde otro lado. Benigno: el resultado que se
    // pedía ya es el que hay.
    if (entry.status === destino) {
      throw ApiError.conflict('TIME_ENTRY_DECISION_MATCHES', 'La jornada ya está en ese estado');
    }
    // La decisión se tomó sobre un estado que ya cambió: dos personas decidieron
    // distinto sobre las mismas horas y eso no se resuelve solo (regla 12).
    if (dto.expectedStatus && dto.expectedStatus !== entry.status) {
      throw ApiError.conflict('TIME_ENTRY_DECISION_CONFLICTS', 'La jornada la decidió alguien más');
    }
  }

  /// La escritura de la decisión, condicionada por el estado leído.
  ///
  /// **El `WHERE status` es lo que vuelve verdad a `expectedStatus`.** Sin él la
  /// comprobación de arriba y esta escritura no son un solo acto: en
  /// `READ COMMITTED` dos decisiones simultáneas leen las dos el mismo estado
  /// viejo, pasan las dos, y la segunda pisa a la primera.
  ///
  /// Y el rastro se escribe **después** de saber que la fila cambió: con cero
  /// filas afectadas, un `recordEdit` dejaría auditado un cambio que no ocurrió.
  private async applyDecision(
    entry: TimeEntry, destino: TimeEntry['status'], dto: ApproveDto,
    tenant: TenantContext, payRateCents: number | null,
  ): Promise<void> {
    const resultado = await this.entries
      .createQueryBuilder()
      .update(TimeEntry)
      .set({
        status: destino,
        approvedBy: { id: tenant.membershipId } as TimeEntry['approvedBy'],
        approvedAt: new Date(),
        decisionReason: dto.reason ?? null,
        ...(payRateCents === null ? {} : { payRateCentsSnapshot: payRateCents }),
      })
      .where('id = :id AND status = :esperado', { id: entry.id, esperado: entry.status })
      .execute();

    if (!resultado.affected) {
      throw ApiError.conflict('TIME_ENTRY_DECISION_CONFLICTS', 'La jornada la decidió alguien más');
    }
    await this.recordEdit(entry, 'status', entry.status, destino, dto.reason, tenant);
  }

  async get(id: string, tenant?: TenantContext): Promise<TimeEntry> {
    const found = await this.entries.findOne({ where: { id, deletedAt: IsNull() } });
    if (!found) throw new NotFoundException('Registro no encontrado');
    // Mismo alcance que list(): sin esto, el detalle sería la puerta que la
    // lista cierra.
    if (tenant && this.soloLoPropio(tenant) && found.membershipId !== tenant.membershipId) {
      throw new NotFoundException('Registro no encontrado');
    }
    return found;
  }

  list(projectId?: string, tenant?: TenantContext): Promise<TimeEntry[]> {
    const soloMias = tenant && this.soloLoPropio(tenant);
    return this.entries.find({
      where: {
        deletedAt: IsNull(),
        ...(projectId ? { project: { id: projectId } } : {}),
        ...(soloMias ? { membership: { id: tenant.membershipId } } : {}),
      },
      order: { clockInAt: 'DESC' },
    });
  }

  /// Un WORKER tiene `time.read` para **sus** horas: `time_entry` lleva la
  /// tarifa congelada y las coordenadas de cada marcaje de sus compañeros.
  private soloLoPropio(tenant: TenantContext): boolean {
    return tenant.role === 'WORKER';
  }

  // El servidor recalcula siempre. Si aceptara la bandera del dispositivo,
  // el control de asistencia sería decorativo.
  private evaluateGeofence(project: Project, lat?: number, lng?: number) {
    const flags: string[] = [];
    if (lat == null || lng == null) {
      flags.push(TIME_ENTRY_FLAGS.NO_LOCATION);
      return { distanceM: null, within: null, flags };
    }
    const site = project.site;
    if (site?.lat == null || site?.lng == null) {
      return { distanceM: null, within: null, flags };
    }
    const distanceM = distanceMeters(site.lat, site.lng, lat, lng);
    const radius = site.geofenceRadiusM ?? DEFAULT_GEOFENCE_M;
    const within = distanceM <= radius;
    if (!within) flags.push(TIME_ENTRY_FLAGS.OUTSIDE_GEOFENCE);
    return { distanceM, within, flags };
  }

  // device_recorded_at lo provee el dispositivo: es dato manipulable.
  private boundDeviceTime(raw: string): { deviceRecordedAt: Date; flags: string[] } {
    const flags: string[] = [];
    const now = new Date();
    let t = new Date(raw);
    const oldest = new Date(now.getTime() - MAX_BACKDATE_DAYS * 86_400_000);
    if (t > now || t < oldest) {
      flags.push(TIME_ENTRY_FLAGS.TIMESTAMP_OUT_OF_RANGE);
      if (t > now) t = now;
    }
    return { deviceRecordedAt: t, flags };
  }

  private methodFor(tenant: TenantContext, targetMembershipId: string): TimeEntry['method'] {
    if (targetMembershipId === tenant.membershipId) return 'SELF';
    return tenant.role === 'FOREMAN' ? 'FOREMAN' : 'ADMIN';
  }

  /// Quién estaba asignado a la obra ese día, directo o por su cuadrilla.
  ///
  /// La ventana es de dos días porque `work_date` es una fecha local y
  /// `device_recorded_at` viaja en UTC: una entrada de la tarde de Maryland cae
  /// en el día siguiente en UTC. Preferible no marcar a un encargado legítimo
  /// que marcar de más — la bandera existe para el que aprueba, no para castigar.
  private async recorderAssignedThatDay(
    membershipId: string, projectId: string, cuando: Date,
  ): Promise<boolean> {
    const dia = cuando.toISOString().slice(0, 10);
    const filas = await this.entries.query<unknown[]>(
      `SELECT 1 FROM project_assignment a
       LEFT JOIN crew_member cm ON cm.crew_id = a.crew_id AND cm.deleted_at IS NULL
         AND a.work_date BETWEEN cm.from_date AND coalesce(cm.to_date, a.work_date)
       WHERE a.project_id = $1 AND a.deleted_at IS NULL
         AND a.work_date BETWEEN ($2::date - 1) AND $2::date
         AND (a.membership_id = $3 OR cm.membership_id = $3)
       LIMIT 1`,
      [projectId, dia, membershipId],
    );
    return filas.length > 0;
  }

  private async assertCanRecordForOthers(tenant: TenantContext): Promise<void> {
    const me = await this.memberships.findOne({ where: { id: tenant.membershipId } });
    if (!me || !['OWNER', 'ADMIN', 'FOREMAN'].includes(me.role)) {
      throw new ForbiddenException('Solo un foreman o admin puede marcar por otra persona');
    }
  }

  private recordEdit(
    entry: TimeEntry, field: string, oldValue: string, newValue: string,
    reason: string | undefined, tenant: TenantContext,
  ): Promise<TimeEntryEdit> {
    return this.edits.save(this.edits.create({
      id: newId(),
      companyId: tenant.companyId,
      timeEntry: { id: entry.id } as TimeEntryEdit['timeEntry'],
      editedBy: { id: tenant.membershipId } as TimeEntryEdit['editedBy'],
      field, oldValue, newValue, reason: reason ?? null,
    }));
  }
}
