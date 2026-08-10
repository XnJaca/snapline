import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { AddressDto } from '../../common/dto/address.dto';
import { Customer } from './customer.entity';

const numeric = {
  to: (v: number | null) => v,
  from: (v: string | null) => (v === null ? null : Number(v)),
};

@Entity('site')
export class Site extends SoftDeletableTenantEntity {
  @ApiPropertyOptional()
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((s: Site) => s.customer)
  customerId!: string;

  // Columna `jsonb`, pero el contrato declara su forma: sin esto sale como
  // objeto vacío y el cliente generado la descarta en silencio (regla 8).
  @ApiProperty({ type: AddressDto })
  @Column({ type: 'jsonb' })
  address!: AddressDto;

  @Column({ type: 'numeric', precision: 9, scale: 6, nullable: true, transformer: numeric })
  lat!: number | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, nullable: true, transformer: numeric })
  lng!: number | null;

  // Null usa el default de la empresa.
  @Column({ type: 'integer', name: 'geofence_radius_m', nullable: true })
  geofenceRadiusM!: number | null;
}
