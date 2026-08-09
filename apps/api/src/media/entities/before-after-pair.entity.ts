import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Project } from '../../projects/entities/project.entity';
import { MediaAsset } from './media-asset.entity';

// Tabla propia: es la pieza de marketing del producto, no una foto más.
@Entity('before_after_pair')
export class BeforeAfterPair extends SoftDeletableTenantEntity {
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((p: BeforeAfterPair) => p.project)
  projectId!: string;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'before_asset_id' })
  beforeAsset!: MediaAsset;

  @RelationId((p: BeforeAfterPair) => p.beforeAsset)
  beforeAssetId!: string;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'after_asset_id' })
  afterAsset!: MediaAsset;

  @RelationId((p: BeforeAfterPair) => p.afterAsset)
  afterAssetId!: string;

  @Column({ type: 'text', nullable: true })
  caption!: string | null;
}
