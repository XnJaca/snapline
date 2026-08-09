import { Column, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { MediaAsset } from '../../media/entities/media-asset.entity';
import { SocialPost } from './social-post.entity';

@Entity('social_post_asset')
export class SocialPostAsset {
  @PrimaryColumn({ type: 'uuid', name: 'social_post_id' })
  socialPostId!: string;

  @PrimaryColumn({ type: 'uuid', name: 'asset_id' })
  assetId!: string;

  @ManyToOne(() => SocialPost, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'social_post_id' })
  socialPost!: SocialPost;

  @ManyToOne(() => MediaAsset, { nullable: false })
  @JoinColumn({ name: 'asset_id' })
  asset!: MediaAsset;

  @Column({ type: 'integer', default: 0 })
  position!: number;
}
