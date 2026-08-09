import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { AppUser } from './app-user.entity';

export type MembershipRole = 'OWNER' | 'ADMIN' | 'FOREMAN' | 'WORKER' | 'ACCOUNTANT';
export type MembershipStatus = 'INVITED' | 'ACTIVE' | 'INACTIVE';
export type EmploymentType = 'W2' | 'CONTRACTOR_1099';

@Entity('membership')
export class Membership extends SoftDeletableTenantEntity {
  @ManyToOne(() => AppUser, { nullable: false })
  @JoinColumn({ name: 'user_id' })
  user!: AppUser;

  @RelationId((m: Membership) => m.user)
  userId!: string;

  @Column({ type: 'enum', enum: ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'], enumName: 'membership_role' })
  role!: MembershipRole;

  // Cambiarla no recalcula horas ya aprobadas: TimeEntry congela su propia copia.
  @Column({ type: 'bigint', name: 'pay_rate_cents', nullable: true, transformer: {
    to: (v: number | null) => v,
    from: (v: string | null) => (v === null ? null : Number(v)),
  } })
  payRateCents!: number | null;

  @Column({ type: 'enum', enum: ['W2', 'CONTRACTOR_1099'], enumName: 'employment_type', name: 'employment_type', nullable: true })
  employmentType!: EmploymentType | null;

  @Column({ type: 'enum', enum: ['INVITED', 'ACTIVE', 'INACTIVE'], enumName: 'membership_status', default: 'INVITED' })
  status!: MembershipStatus;

  @Column({ type: 'timestamptz', name: 'invited_at', nullable: true })
  invitedAt!: Date | null;

  @Column({ type: 'timestamptz', name: 'joined_at', nullable: true })
  joinedAt!: Date | null;
}
