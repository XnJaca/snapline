import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Customer } from './customer.entity';

const numeric = {
  to: (v: number | null) => v,
  from: (v: string | null) => (v === null ? null : Number(v)),
};

@Entity('site')
export class Site extends SoftDeletableTenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((s: Site) => s.customer)
  customerId!: string;

  @Column({ type: 'jsonb' })
  address!: Record<string, unknown>;

  @Column({ type: 'numeric', precision: 9, scale: 6, nullable: true, transformer: numeric })
  lat!: number | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, nullable: true, transformer: numeric })
  lng!: number | null;

  // Null usa el default de la empresa.
  @Column({ type: 'integer', name: 'geofence_radius_m', nullable: true })
  geofenceRadiusM!: number | null;
}
