import { Column, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { MediaAsset } from '../../media/entities/media-asset.entity';
import { PublishedProject } from './published-project.entity';

@Entity('published_project_asset')
export class PublishedProjectAsset {
  @PrimaryColumn({ type: 'uuid', name: 'published_project_id' })
  publishedProjectId!: string;

  @PrimaryColumn({ type: 'uuid', name: 'asset_id' })
  assetId!: string;

  @ManyToOne(() => PublishedProject, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'published_project_id' })
  publishedProject!: PublishedProject;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'asset_id' })
  asset!: MediaAsset;

  @Column({ type: 'integer', default: 0 })
  position!: number;
}
