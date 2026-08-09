import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryColumn, RelationId } from 'typeorm';
import { Membership } from '../../auth/entities/membership.entity';

@Entity('audit_log')
export class AuditLog {
  @PrimaryColumn({ type: 'uuid' })
  id!: string;

  @Column({ type: 'uuid', name: 'company_id' })
  companyId!: string;

  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'actor_membership_id' })
  actor!: Membership | null;

  @RelationId((l: AuditLog) => l.actor)
  actorMembershipId!: string | null;

  @Column({ type: 'text' })
  entity!: string;

  @Column({ type: 'uuid', name: 'entity_id' })
  entityId!: string;

  @Column({ type: 'text' })
  action!: string;

  @Column({ type: 'jsonb', name: 'old_value', nullable: true })
  oldValue!: Record<string, unknown> | null;

  @Column({ type: 'jsonb', name: 'new_value', nullable: true })
  newValue!: Record<string, unknown> | null;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt!: Date;
}
