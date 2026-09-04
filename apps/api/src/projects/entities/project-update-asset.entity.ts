import { Column, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { MediaAsset } from '../../media/entities/media-asset.entity';
import { ProjectUpdate } from './project-update.entity';

@Entity('project_update_asset')
export class ProjectUpdateAsset {
  @PrimaryColumn({ type: 'uuid', name: 'update_id' })
  updateId!: string;

  @PrimaryColumn({ type: 'uuid', name: 'asset_id' })
  assetId!: string;

  @ManyToOne(() => ProjectUpdate, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'update_id' })
  update!: ProjectUpdate;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'asset_id' })
  asset!: MediaAsset;

  @Column({ type: 'integer', default: 0 })
  position!: number;
}
