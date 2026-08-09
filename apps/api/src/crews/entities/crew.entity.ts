import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';

@Entity('crew')
export class Crew extends SoftDeletableTenantEntity {
  @Column({ type: 'text' })
  name!: string;

  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'foreman_membership_id' })
  foreman!: Membership | null;

  @RelationId((c: Crew) => c.foreman)
  foremanMembershipId!: string | null;

  @Column({ type: 'text', nullable: true })
  color!: string | null;
}
