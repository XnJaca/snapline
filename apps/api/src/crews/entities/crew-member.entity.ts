import { ApiPropertyOptional } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Crew } from './crew.entity';

// La base impide rangos solapados con un constraint de exclusión.
@Entity('crew_member')
export class CrewMember extends SoftDeletableTenantEntity {
  // Opcional en el contrato: el pull manda la fila sin embeber la relación, y
  // un cliente que la exija revienta al parsear. El id viaja siempre.
  @ApiPropertyOptional()
  @ManyToOne(() => Crew, { nullable: false })
  @JoinColumn({ name: 'crew_id' })
  crew!: Crew;

  @RelationId((cm: CrewMember) => cm.crew)
  crewId!: string;

  @ApiPropertyOptional()
  @ManyToOne(() => Membership, { nullable: false })
  @JoinColumn({ name: 'membership_id' })
  membership!: Membership;

  @RelationId((cm: CrewMember) => cm.membership)
  membershipId!: string;

  @Column({ type: 'date', name: 'from_date' })
  fromDate!: string;

  @Column({ type: 'date', name: 'to_date', nullable: true })
  toDate!: string | null;
}
