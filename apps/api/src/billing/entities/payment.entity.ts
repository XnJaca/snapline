import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Invoice } from './invoice.entity';

export type PaymentMethod = 'CHECK' | 'CASH' | 'ACH' | 'CARD' | 'ZELLE' | 'OTHER';

@Entity('payment')
export class Payment extends SoftDeletableTenantEntity {
  @ManyToOne(() => Invoice, { nullable: false })
  @JoinColumn({ name: 'invoice_id' })
  invoice!: Invoice;

  @RelationId((p: Payment) => p.invoice)
  invoiceId!: string;

  @Column({ type: 'bigint', name: 'amount_cents', transformer: { to: (v: number) => v, from: (v: string) => Number(v) } })
  amountCents!: number;

  @Column({ type: 'enum', enum: ['CHECK', 'CASH', 'ACH', 'CARD', 'ZELLE', 'OTHER'], enumName: 'payment_method' })
  method!: PaymentMethod;

  @Column({ type: 'timestamptz', name: 'received_at' })
  receivedAt!: Date;

  @Column({ type: 'text', nullable: true })
  reference!: string | null;

  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'recorded_by_membership_id' })
  recordedBy!: Membership | null;

  @RelationId((p: Payment) => p.recordedBy)
  recordedByMembershipId!: string | null;

  // Cobrar dos veces por un reintento de red sería el peor bug del módulo.
  @Column({ type: 'text', name: 'idempotency_key', nullable: true })
  idempotencyKey!: string | null;
}
