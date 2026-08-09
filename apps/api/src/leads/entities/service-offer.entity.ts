import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { ServiceItem } from '../../catalog/entities/service-item.entity';

@Entity('service_offer')
export class ServiceOffer extends SoftDeletableTenantEntity {
  @ManyToOne(() => ServiceItem, { nullable: true })
  @JoinColumn({ name: 'service_item_id' })
  serviceItem!: ServiceItem | null;

  @RelationId((o: ServiceOffer) => o.serviceItem)
  serviceItemId!: string | null;

  @Column({ type: 'text' })
  title!: string;

  @Column({ type: 'text', nullable: true })
  pitch!: string | null;

  @Column({ type: 'jsonb', nullable: true })
  target!: Record<string, unknown> | null;

  @Column({ type: 'boolean', default: true })
  active!: boolean;
}
