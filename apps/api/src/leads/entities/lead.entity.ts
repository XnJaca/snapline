import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Project } from '../../projects/entities/project.entity';
import { ServiceOffer } from './service-offer.entity';

export type LeadStatus = 'NEW' | 'CONTACTED' | 'CONVERTED' | 'DISCARDED';

@Entity('lead')
export class Lead extends SoftDeletableTenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((l: Lead) => l.customer)
  customerId!: string;

  @ManyToOne(() => ServiceOffer, { nullable: true })
  @JoinColumn({ name: 'offer_id' })
  offer!: ServiceOffer | null;

  @RelationId((l: Lead) => l.offer)
  offerId!: string | null;

  @ManyToOne(() => Project, { nullable: true })
  @JoinColumn({ name: 'source_project_id' })
  sourceProject!: Project | null;

  @RelationId((l: Lead) => l.sourceProject)
  sourceProjectId!: string | null;

  @Column({ type: 'enum', enum: ['NEW', 'CONTACTED', 'CONVERTED', 'DISCARDED'], enumName: 'lead_status', default: 'NEW' })
  status!: LeadStatus;

  // Es lo que prueba que el ciclo cierra. Sin este dato, la venta cruzada es una corazonada.
  @ManyToOne(() => Project, { nullable: true })
  @JoinColumn({ name: 'converted_project_id' })
  convertedProject!: Project | null;

  @RelationId((l: Lead) => l.convertedProject)
  convertedProjectId!: string | null;

  @Column({ type: 'text', nullable: true })
  notes!: string | null;
}
