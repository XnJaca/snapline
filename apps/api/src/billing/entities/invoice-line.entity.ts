import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { TenantEntity } from '../../common/entities/base.entity';
import { ServiceItem, ServiceUnit } from '../../catalog/entities/service-item.entity';
import { Invoice } from './invoice.entity';

const cents = { to: (v: number) => v, from: (v: string) => Number(v) };
const decimal = { to: (v: number) => v, from: (v: string) => Number(v) };

// Los _snapshot copian del catálogo. Referenciarlo vivo reescribiría documentos emitidos.
@Entity('invoice_line')
export class InvoiceLine extends TenantEntity {
  @ManyToOne(() => Invoice, (e) => e.lines, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'invoice_id' })
  invoice!: Invoice;

  @RelationId((l: InvoiceLine) => l.invoice)
  invoiceId!: string;

  @Column({ type: 'integer' })
  position!: number;

  // Solo para reportes: nunca se lee para mostrar la línea.
  @ManyToOne(() => ServiceItem, { nullable: true })
  @JoinColumn({ name: 'service_item_id' })
  serviceItem!: ServiceItem | null;

  @RelationId((l: InvoiceLine) => l.serviceItem)
  serviceItemId!: string | null;

  @Column({ type: 'text', name: 'name_snapshot' })
  nameSnapshot!: string;

  @Column({ type: 'text', name: 'description_snapshot', nullable: true })
  descriptionSnapshot!: string | null;

  @Column({ type: 'enum', enum: ['HOUR', 'SQFT', 'LINEAR_FT', 'EACH', 'JOB'], enumName: 'service_unit', name: 'unit_snapshot' })
  unitSnapshot!: ServiceUnit;

  @Column({ type: 'boolean', name: 'taxable_snapshot' })
  taxableSnapshot!: boolean;

  @Column({ type: 'bigint', name: 'unit_price_cents_snapshot', transformer: cents })
  unitPriceCentsSnapshot!: number;

  @Column({ type: 'numeric', precision: 12, scale: 3, transformer: decimal })
  qty!: number;

  @Column({ type: 'bigint', name: 'amount_cents', transformer: cents })
  amountCents!: number;
}
