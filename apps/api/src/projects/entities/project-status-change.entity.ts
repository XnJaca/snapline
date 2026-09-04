import { ApiPropertyOptional } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Project, ProjectStatus } from './project.entity';

const STATUSES = ['LEAD', 'ESTIMATED', 'SCHEDULED', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED'] as const;

// Append-only: una transición que ocurrió, ocurrió. Con `from_status` y
// `changed_by` en nulo es el hito que sembró la migración — dice cómo estaba la
// obra cuando esto empezó a registrarse, no que haya nacido así.
@Entity('project_status_change')
export class ProjectStatusChange extends SoftDeletableTenantEntity {
  @ApiPropertyOptional()
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((c: ProjectStatusChange) => c.project)
  projectId!: string;

  @Column({ type: 'enum', enum: STATUSES, enumName: 'project_status', name: 'from_status', nullable: true })
  fromStatus!: ProjectStatus | null;

  @Column({ type: 'enum', enum: STATUSES, enumName: 'project_status', name: 'to_status' })
  toStatus!: ProjectStatus;

  @ApiPropertyOptional()
  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'changed_by_membership_id' })
  changedBy!: Membership | null;

  @RelationId((c: ProjectStatusChange) => c.changedBy)
  changedByMembershipId!: string | null;

  // Regla 10: con la bandeja de por medio nunca son la misma.
  @Column({ type: 'timestamptz', name: 'device_recorded_at' })
  deviceRecordedAt!: Date;

  @Column({ type: 'timestamptz', name: 'server_received_at' })
  serverReceivedAt!: Date;
}
