import { Column, Entity, JoinColumn, ManyToOne, OneToMany, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Project } from '../../projects/entities/project.entity';
import { Estimate } from './estimate.entity';
import { InvoiceLine } from './invoice-line.entity';

export type InvoiceStatus = 'DRAFT' | 'SENT' | 'PARTIAL' | 'PAID' | 'OVERDUE' | 'VOID';

const cents = { to: (v: number) => v, from: (v: string) => Number(v) };

// Una factura enviada no se edita: se anula (VOID) y se emite otra.
@Entity('invoice')
export class Invoice extends SoftDeletableTenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((i: Invoice) => i.customer)
  customerId!: string;

  @ManyToOne(() => Project, { nullable: true })
  @JoinColumn({ name: 'project_id' })
  project!: Project | null;

  @RelationId((i: Invoice) => i.project)
  projectId!: string | null;

  @ManyToOne(() => Estimate, { nullable: true })
  @JoinColumn({ name: 'estimate_id' })
  estimate!: Estimate | null;

  @RelationId((i: Invoice) => i.estimate)
  estimateId!: string | null;

  @Column({ type: 'text', nullable: true })
  number!: string | null;

  @Column({ type: 'enum', enum: ['DRAFT', 'SENT', 'PARTIAL', 'PAID', 'OVERDUE', 'VOID'], enumName: 'invoice_status', default: 'DRAFT' })
  status!: InvoiceStatus;

  @Column({ type: 'timestamptz', name: 'issued_at', nullable: true })
  issuedAt!: Date | null;

  @Column({ type: 'timestamptz', name: 'due_at', nullable: true })
  dueAt!: Date | null;

  @Column({ type: 'bigint', name: 'subtotal_cents', default: 0, transformer: cents })
  subtotalCents!: number;

  @Column({ type: 'bigint', name: 'tax_cents', default: 0, transformer: cents })
  taxCents!: number;

  @Column({ type: 'bigint', name: 'total_cents', default: 0, transformer: cents })
  totalCents!: number;

  // Derivado: total menos la suma de pagos. Se recalcula, no se edita.
  @Column({ type: 'bigint', name: 'balance_cents', default: 0, transformer: cents })
  balanceCents!: number;

  @Column({ type: 'timestamptz', name: 'voided_at', nullable: true })
  voidedAt!: Date | null;

  @OneToMany(() => InvoiceLine, (l) => l.invoice)
  lines!: InvoiceLine[];
}
