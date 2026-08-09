import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryColumn, RelationId } from 'typeorm';
import { MediaAsset } from './media-asset.entity';

export type MediaTagKind = 'BEFORE' | 'DURING' | 'AFTER' | 'DETAIL' | 'PROBLEM' | 'RECEIPT';

@Entity('media_tag')
export class MediaTag {
  @PrimaryColumn({ type: 'uuid' })
  id!: string;

  @Column({ type: 'uuid', name: 'company_id' })
  companyId!: string;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'asset_id' })
  asset!: MediaAsset;

  @RelationId((t: MediaTag) => t.asset)
  assetId!: string;

  @Column({ type: 'enum', enum: ['BEFORE', 'DURING', 'AFTER', 'DETAIL', 'PROBLEM', 'RECEIPT'], enumName: 'media_tag_kind' })
  tag!: MediaTagKind;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt!: Date;
}
