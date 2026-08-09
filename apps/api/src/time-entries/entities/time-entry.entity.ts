import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Project } from '../../projects/entities/project.entity';

export type TimeEntryMethod = 'SELF' | 'FOREMAN' | 'ADMIN';
export type TimeEntryStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

// No bloquean: informan la aprobación.
export const TIME_ENTRY_FLAGS = {
  OUTSIDE_GEOFENCE: 'OUTSIDE_GEOFENCE',
  NO_PHOTO: 'NO_PHOTO',
  MOCK_LOCATION: 'MOCK_LOCATION',
  NO_LOCATION: 'NO_LOCATION',
  SHIFT_TOO_LONG: 'SHIFT_TOO_LONG',
  MISSING_CLOCK_OUT: 'MISSING_CLOCK_OUT',
  MANUALLY_EDITED: 'MANUALLY_EDITED',
  OVERLAPPING_PROJECTS: 'OVERLAPPING_PROJECTS',
  TIMESTAMP_OUT_OF_RANGE: 'TIMESTAMP_OUT_OF_RANGE',
} as const;

const bigintNumber = {
  to: (v: number | null) => v,
  from: (v: string | null) => (v === null ? null : Number(v)),
};
const numeric = bigintNumber;

// Evidencia laboral: un trigger bloquea DELETE, se corrige con deleted_at + TimeEntryEdit.
@Entity('time_entry')
export class TimeEntry extends SoftDeletableTenantEntity {
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((t: TimeEntry) => t.project)
  projectId!: string;

  @ManyToOne(() => Membership, { nullable: false })
  @JoinColumn({ name: 'membership_id' })
  membership!: Membership;

  @RelationId((t: TimeEntry) => t.membership)
  membershipId!: string;

  @Column({ type: 'timestamptz', name: 'clock_in_at' })
  clockInAt!: Date;

  @Column({ type: 'timestamptz', name: 'clock_out_at', nullable: true })
  clockOutAt!: Date | null;

  @Column({ type: 'integer', name: 'break_minutes', default: 0 })
  breakMinutes!: number;

  @Column({ type: 'numeric', precision: 9, scale: 6, name: 'clock_in_lat', nullable: true, transformer: numeric })
  clockInLat!: number | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, name: 'clock_in_lng', nullable: true, transformer: numeric })
  clockInLng!: number | null;

  @Column({ type: 'integer', name: 'clock_in_accuracy_m', nullable: true })
  clockInAccuracyM!: number | null;

  // Derivada en el servidor desde lat/lng contra el sitio.
  @Column({ type: 'integer', name: 'clock_in_distance_m', nullable: true })
  clockInDistanceM!: number | null;

  // Derivada en el servidor. Nunca se acepta del dispositivo.
  @Column({ type: 'boolean', name: 'clock_in_within_geofence', nullable: true })
  clockInWithinGeofence!: boolean | null;

  @Column({ type: 'uuid', name: 'clock_in_photo_id', nullable: true })
  clockInPhotoId!: string | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, name: 'clock_out_lat', nullable: true, transformer: numeric })
  clockOutLat!: number | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, name: 'clock_out_lng', nullable: true, transformer: numeric })
  clockOutLng!: number | null;

  @Column({ type: 'integer', name: 'clock_out_accuracy_m', nullable: true })
  clockOutAccuracyM!: number | null;

  @Column({ type: 'integer', name: 'clock_out_distance_m', nullable: true })
  clockOutDistanceM!: number | null;

  @Column({ type: 'boolean', name: 'clock_out_within_geofence', nullable: true })
  clockOutWithinGeofence!: boolean | null;

  @Column({ type: 'uuid', name: 'clock_out_photo_id', nullable: true })
  clockOutPhotoId!: string | null;

  @Column({ type: 'enum', enum: ['SELF', 'FOREMAN', 'ADMIN'], enumName: 'time_entry_method', default: 'SELF' })
  method!: TimeEntryMethod;

  // No siempre es de quién son las horas: el foreman marca por los suyos.
  @ManyToOne(() => Membership, { nullable: false })
  @JoinColumn({ name: 'recorded_by_membership_id' })
  recordedBy!: Membership;

  @RelationId((t: TimeEntry) => t.recordedBy)
  recordedByMembershipId!: string;

  @Column({ type: 'text', name: 'device_id', nullable: true })
  deviceId!: string | null;

  @Column({ type: 'boolean', name: 'is_mock_location', default: false })
  isMockLocation!: boolean;

  @Column({ type: 'boolean', name: 'recorded_offline', default: false })
  recordedOffline!: boolean;

  // Dato del dispositivo, manipulable: el servidor lo acota.
  @Column({ type: 'timestamptz', name: 'device_recorded_at' })
  deviceRecordedAt!: Date;

  @Column({ type: 'timestamptz', name: 'server_received_at', default: () => 'now()' })
  serverReceivedAt!: Date;

  @Column({ type: 'enum', enum: ['PENDING', 'APPROVED', 'REJECTED'], enumName: 'time_entry_status', default: 'PENDING' })
  status!: TimeEntryStatus;

  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'approved_by_membership_id' })
  approvedBy!: Membership | null;

  @RelationId((t: TimeEntry) => t.approvedBy)
  approvedByMembershipId!: string | null;

  @Column({ type: 'timestamptz', name: 'approved_at', nullable: true })
  approvedAt!: Date | null;

  // Congelada al aprobar. La base la exige si status=APPROVED.
  @Column({ type: 'bigint', name: 'pay_rate_cents_snapshot', nullable: true, transformer: bigintNumber })
  payRateCentsSnapshot!: number | null;

  @Column({ type: 'text', array: true, default: () => `'{}'` })
  flags!: string[];
}
