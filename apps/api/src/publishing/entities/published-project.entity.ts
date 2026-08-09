import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { TenantEntity } from '../../common/entities/base.entity';
import { Project } from '../../projects/entities/project.entity';
import { MediaAsset } from '../../media/entities/media-asset.entity';
import { Testimonial } from './testimonial.entity';

// Se despublica con unpublished_at, no se borra: el link ya está indexado.
@Entity('published_project')
export class PublishedProject extends TenantEntity {
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((p: PublishedProject) => p.project)
  projectId!: string;

  @Column({ type: 'citext' })
  slug!: string;

  @Column({ type: 'text' })
  title!: string;

  @Column({ type: 'text', nullable: true })
  summary!: string | null;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'hero_asset_id' })
  heroAsset!: MediaAsset;

  @RelationId((p: PublishedProject) => p.heroAsset)
  heroAssetId!: string;

  @Column({ type: 'text', name: 'service_type', nullable: true })
  serviceType!: string | null;

  @Column({ type: 'text', nullable: true })
  city!: string | null;

  @ManyToOne(() => Testimonial, { nullable: true })
  @JoinColumn({ name: 'testimonial_id' })
  testimonial!: Testimonial | null;

  @RelationId((p: PublishedProject) => p.testimonial)
  testimonialId!: string | null;

  @Column({ type: 'timestamptz', name: 'published_at', default: () => 'now()' })
  publishedAt!: Date;

  @Column({ type: 'timestamptz', name: 'unpublished_at', nullable: true })
  unpublishedAt!: Date | null;
}
