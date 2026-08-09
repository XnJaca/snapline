import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Project } from '../../projects/entities/project.entity';

export type SocialPlatform = 'INSTAGRAM' | 'FACEBOOK' | 'GOOGLE' | 'TIKTOK' | 'OTHER';
export type SocialPostStatus = 'SUGGESTED' | 'SCHEDULED' | 'POSTED';

// Registra qué material ya se usó, para no repetir el mismo antes/después.
@Entity('social_post')
export class SocialPost extends SoftDeletableTenantEntity {
  @ManyToOne(() => Project, { nullable: true })
  @JoinColumn({ name: 'source_project_id' })
  sourceProject!: Project | null;

  @RelationId((p: SocialPost) => p.sourceProject)
  sourceProjectId!: string | null;

  @Column({ type: 'enum', enum: ['INSTAGRAM', 'FACEBOOK', 'GOOGLE', 'TIKTOK', 'OTHER'], enumName: 'social_platform' })
  platform!: SocialPlatform;

  @Column({ type: 'text', nullable: true })
  content!: string | null;

  @Column({ type: 'enum', enum: ['SUGGESTED', 'SCHEDULED', 'POSTED'], enumName: 'social_post_status', default: 'SUGGESTED' })
  status!: SocialPostStatus;

  @Column({ type: 'timestamptz', name: 'scheduled_for', nullable: true })
  scheduledFor!: Date | null;

  @Column({ type: 'timestamptz', name: 'posted_at', nullable: true })
  postedAt!: Date | null;
}
