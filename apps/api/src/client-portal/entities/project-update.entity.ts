import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Project } from '../../projects/entities/project.entity';
import { MediaVisibility } from '../../media/entities/media-asset.entity';

// Nada llega al cliente sin published_at, y la base exige aprobación para setearlo.
@Entity('project_update')
export class ProjectUpdate extends SoftDeletableTenantEntity {
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((u: ProjectUpdate) => u.project)
  projectId!: string;

  @ManyToOne(() => Membership, { nullable: false })
  @JoinColumn({ name: 'author_membership_id' })
  author!: Membership;

  @RelationId((u: ProjectUpdate) => u.author)
  authorMembershipId!: string;

  @Column({ type: 'text' })
  body!: string;

  @Column({ type: 'enum', enum: ['INTERNAL', 'CLIENT', 'PUBLIC'], enumName: 'media_visibility', default: 'INTERNAL' })
  visibility!: MediaVisibility;

  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'approved_by_membership_id' })
  approvedBy!: Membership | null;

  @RelationId((u: ProjectUpdate) => u.approvedBy)
  approvedByMembershipId!: string | null;

  @Column({ type: 'timestamptz', name: 'published_at', nullable: true })
  publishedAt!: Date | null;
}
