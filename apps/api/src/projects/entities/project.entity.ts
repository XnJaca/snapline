import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Site } from '../../customers/entities/site.entity';

export type ProjectStatus =
  | 'LEAD' | 'ESTIMATED' | 'SCHEDULED' | 'IN_PROGRESS' | 'ON_HOLD' | 'COMPLETED' | 'CANCELLED';

export type ClientVisibilityMode = 'STAGES' | 'PROGRESS';

export type ClientStage = 'INICIO' | 'EN_PROCESO' | 'FINALIZADO';

const CLIENT_STAGE: Record<ProjectStatus, ClientStage> = {
  LEAD: 'INICIO',
  ESTIMATED: 'INICIO',
  SCHEDULED: 'INICIO',
  IN_PROGRESS: 'EN_PROCESO',
  ON_HOLD: 'EN_PROCESO',
  COMPLETED: 'FINALIZADO',
  CANCELLED: 'FINALIZADO',
};

@Entity('project')
export class Project extends SoftDeletableTenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((p: Project) => p.customer)
  customerId!: string;

  @ManyToOne(() => Site, { nullable: false })
  @JoinColumn({ name: 'site_id' })
  site!: Site;

  @RelationId((p: Project) => p.site)
  siteId!: string;

  @Column({ type: 'text' })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ type: 'text', name: 'service_type', nullable: true })
  serviceType!: string | null;

  @Column({ type: 'enum', enum: ['LEAD', 'ESTIMATED', 'SCHEDULED', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED'], enumName: 'project_status', default: 'LEAD' })
  status!: ProjectStatus;

  // Arranca en STAGES a propósito; pasar a PROGRESS es decisión activa.
  @Column({ type: 'enum', enum: ['STAGES', 'PROGRESS'], enumName: 'client_visibility_mode', name: 'client_visibility_mode', default: 'STAGES' })
  clientVisibilityMode!: ClientVisibilityMode;

  @Column({ type: 'date', name: 'start_date', nullable: true })
  startDate!: string | null;

  @Column({ type: 'date', name: 'target_end_date', nullable: true })
  targetEndDate!: string | null;

  @Column({ type: 'date', name: 'actual_end_date', nullable: true })
  actualEndDate!: string | null;

  @Column({ type: 'timestamptz', name: 'published_at', nullable: true })
  publishedAt!: Date | null;

  get clientStage(): ClientStage {
    return CLIENT_STAGE[this.status];
  }
}
