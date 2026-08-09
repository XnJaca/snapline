import { Column, Entity, JoinColumn, ManyToOne, OneToMany, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Project } from '../../projects/entities/project.entity';
import { EstimateLine } from './estimate-line.entity';

export type EstimateStatus = 'DRAFT' | 'SENT' | 'VIEWED' | 'ACCEPTED' | 'DECLINED' | 'EXPIRED';

const cents = {
  to: (v: number) => v,
  from: (v: string) => Number(v),
};

@Entity('estimate')
export class Estimate extends SoftDeletableTenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((e: Estimate) => e.customer)
  customerId!: string;

  @ManyToOne(() => Project, { nullable: true })
  @JoinColumn({ name: 'project_id' })
  project!: Project | null;

  @RelationId((e: Estimate) => e.project)
  projectId!: string | null;

  // Lo asigna el servidor al enviar, no el cliente.
  @Column({ type: 'text', nullable: true })
  number!: string | null;

  @Column({ type: 'enum', enum: ['DRAFT', 'SENT', 'VIEWED', 'ACCEPTED', 'DECLINED', 'EXPIRED'], enumName: 'estimate_status', default: 'DRAFT' })
  status!: EstimateStatus;

  @Column({ type: 'timestamptz', name: 'issued_at', nullable: true })
  issuedAt!: Date | null;

  @Column({ type: 'timestamptz', name: 'expires_at', nullable: true })
  expiresAt!: Date | null;

  @Column({ type: 'bigint', name: 'subtotal_cents', default: 0, transformer: cents })
  subtotalCents!: number;

  @Column({ type: 'bigint', name: 'tax_cents', default: 0, transformer: cents })
  taxCents!: number;

  @Column({ type: 'bigint', name: 'total_cents', default: 0, transformer: cents })
  totalCents!: number;

  @Column({ type: 'text', nullable: true })
  terms!: string | null;

  @Column({ type: 'timestamptz', name: 'accepted_at', nullable: true })
  acceptedAt!: Date | null;

  @Column({ type: 'uuid', name: 'accepted_signature_asset_id', nullable: true })
  acceptedSignatureAssetId!: string | null;

  @Column({ type: 'inet', name: 'accepted_ip', nullable: true })
  acceptedIp!: string | null;

  @OneToMany(() => EstimateLine, (l) => l.estimate)
  lines!: EstimateLine[];
}
