import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryColumn, RelationId } from 'typeorm';
import { MediaAsset } from './media-asset.entity';

export const MEDIA_TAG_KINDS = ['BEFORE', 'DURING', 'AFTER', 'DETAIL', 'PROBLEM', 'RECEIPT'] as const;
export type MediaTagKind = (typeof MEDIA_TAG_KINDS)[number];

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

  @Column({ type: 'enum', enum: MEDIA_TAG_KINDS, enumName: 'media_tag_kind' })
  tag!: MediaTagKind;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt!: Date;
}
