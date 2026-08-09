import { Column, Entity } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';

@Entity('tax_rate')
export class TaxRate extends SoftDeletableTenantEntity {
  @Column({ type: 'text' })
  name!: string;

  // Basis points: 600 = 6%.
  @Column({ type: 'integer', name: 'rate_bps' })
  rateBps!: number;

  @Column({ type: 'boolean', default: true })
  active!: boolean;
}
