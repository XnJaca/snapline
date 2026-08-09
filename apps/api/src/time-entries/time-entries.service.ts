import { ApiError } from '../common/errors/api-error';
import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
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
      method: targetMembershipId === tenant.membershipId ? 'SELF' : 'FOREMAN',
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

    // Nadie aprueba sus propias horas, ni siquiera un OWNER.
    if (entry.membershipId === tenant.membershipId) {
      throw ApiError.forbidden('CANNOT_APPROVE_OWN_HOURS', 'No se pueden aprobar las horas propias');
    }
    if (!entry.clockOutAt) throw new BadRequestException('El registro sigue abierto');
    if (entry.status === 'APPROVED') throw new ConflictException('Ya está aprobado');

    const membership = await this.memberships.findOne({ where: { id: entry.membershipId } });
    if (!membership?.payRateCents) {
      throw ApiError.badRequest('PAY_RATE_MISSING', 'La persona no tiene tarifa definida');
    }

    await this.entries.update({ id }, {
      status: 'APPROVED',
      approvedBy: { id: tenant.membershipId } as TimeEntry['approvedBy'],
      approvedAt: new Date(),
      payRateCentsSnapshot: membership.payRateCents,
    });
    await this.recordEdit(entry, 'status', entry.status, 'APPROVED', dto.reason, tenant);
    return this.get(id);
  }

  @Transactional()
  async reject(id: string, dto: ApproveDto, tenant: TenantContext): Promise<TimeEntry> {
    const entry = await this.get(id);
    if (entry.membershipId === tenant.membershipId) {
      throw ApiError.forbidden('CANNOT_APPROVE_OWN_HOURS', 'No se pueden rechazar las horas propias');
    }
    await this.entries.update({ id }, {
      status: 'REJECTED',
      approvedBy: { id: tenant.membershipId } as TimeEntry['approvedBy'],
      approvedAt: new Date(),
    });
    await this.recordEdit(entry, 'status', entry.status, 'REJECTED', dto.reason, tenant);
    return this.get(id);
  }

  async get(id: string): Promise<TimeEntry> {
    const found = await this.entries.findOne({ where: { id, deletedAt: IsNull() } });
    if (!found) throw new NotFoundException('Registro no encontrado');
    return found;
  }

  list(projectId?: string): Promise<TimeEntry[]> {
    return this.entries.find({
      where: { deletedAt: IsNull(), ...(projectId ? { project: { id: projectId } } : {}) },
      order: { clockInAt: 'DESC' },
    });
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
