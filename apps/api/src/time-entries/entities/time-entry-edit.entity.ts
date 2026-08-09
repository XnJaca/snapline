import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryColumn, RelationId } from 'typeorm';
import { Membership } from '../../auth/entities/membership.entity';
import { TimeEntry } from './time-entry.entity';

// No extiende SoftDeletable: una entrada de auditoría no se borra ni se edita.
@Entity('time_entry_edit')
export class TimeEntryEdit {
  @PrimaryColumn({ type: 'uuid' })
  id!: string;

  @Column({ type: 'uuid', name: 'company_id' })
  companyId!: string;

  @ManyToOne(() => TimeEntry, { nullable: false })
  @JoinColumn({ name: 'time_entry_id' })
  timeEntry!: TimeEntry;

  @RelationId((e: TimeEntryEdit) => e.timeEntry)
  timeEntryId!: string;

  @ManyToOne(() => Membership, { nullable: false })
  @JoinColumn({ name: 'edited_by_membership_id' })
  editedBy!: Membership;

  @RelationId((e: TimeEntryEdit) => e.editedBy)
  editedByMembershipId!: string;

  @Column({ type: 'text' })
  field!: string;

  @Column({ type: 'text', name: 'old_value', nullable: true })
  oldValue!: string | null;

  @Column({ type: 'text', name: 'new_value', nullable: true })
  newValue!: string | null;

  @Column({ type: 'text', nullable: true })
  reason!: string | null;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt!: Date;
}
