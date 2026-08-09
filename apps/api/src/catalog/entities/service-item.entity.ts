import { Column, Entity } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';

export type ServiceUnit = 'HOUR' | 'SQFT' | 'LINEAR_FT' | 'EACH' | 'JOB';

const cents = {
  to: (v: number | null) => v,
  from: (v: string | null) => (v === null ? null : Number(v)),
};

@Entity('service_item')
export class ServiceItem extends SoftDeletableTenantEntity {
  @Column({ type: 'text', nullable: true })
  code!: string | null;

  @Column({ type: 'text' })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ type: 'enum', enum: ['HOUR', 'SQFT', 'LINEAR_FT', 'EACH', 'JOB'], enumName: 'service_unit' })
  unit!: ServiceUnit;

  @Column({ type: 'bigint', name: 'unit_price_cents', transformer: cents })
  unitPriceCents!: number;

  // Habilita ver margen, que es lo que hoy no existe al estimar a mano.
  @Column({ type: 'bigint', name: 'cost_cents', nullable: true, transformer: cents })
  costCents!: number | null;

  @Column({ type: 'boolean', default: false })
  taxable!: boolean;

  @Column({ type: 'text', nullable: true })
  category!: string | null;

  @Column({ type: 'boolean', default: true })
  active!: boolean;
}
