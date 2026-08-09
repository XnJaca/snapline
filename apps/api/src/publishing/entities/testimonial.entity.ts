import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Project } from '../../projects/entities/project.entity';

@Entity('testimonial')
export class Testimonial extends SoftDeletableTenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((t: Testimonial) => t.customer)
  customerId!: string;

  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((t: Testimonial) => t.project)
  projectId!: string;

  @Column({ type: 'integer', nullable: true })
  rating!: number | null;

  @Column({ type: 'text' })
  body!: string;

  @Column({ type: 'timestamptz', name: 'approved_at', nullable: true })
  approvedAt!: Date | null;

  @Column({ type: 'timestamptz', name: 'published_at', nullable: true })
  publishedAt!: Date | null;
}
