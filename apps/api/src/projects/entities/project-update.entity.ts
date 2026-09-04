import { ApiPropertyOptional } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Project } from './project.entity';
import { MediaVisibility } from '../../media/entities/media-asset.entity';

// La bitácora de la obra. El portal del cliente es uno de sus destinos, no su
// dueño: nada le llega sin `published_at`, y la base exige aprobación para
// setearlo. `PUBLIC` lo rechaza un CHECK — publicar al portafolio es otro acto.
@Entity('project_update')
export class ProjectUpdate extends SoftDeletableTenantEntity {
  @ApiPropertyOptional()
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((u: ProjectUpdate) => u.project)
  projectId!: string;

  @ApiPropertyOptional()
  @ManyToOne(() => Membership, { nullable: false })
  @JoinColumn({ name: 'author_membership_id' })
  author!: Membership;

  @RelationId((u: ProjectUpdate) => u.author)
  authorMembershipId!: string;

  @Column({ type: 'text' })
  body!: string;

  @Column({ type: 'enum', enum: ['INTERNAL', 'CLIENT', 'PUBLIC'], enumName: 'media_visibility', default: 'INTERNAL' })
  visibility!: MediaVisibility;

  @ApiPropertyOptional()
  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'approved_by_membership_id' })
  approvedBy!: Membership | null;

  @RelationId((u: ProjectUpdate) => u.approvedBy)
  approvedByMembershipId!: string | null;

  @Column({ type: 'timestamptz', name: 'published_at', nullable: true })
  publishedAt!: Date | null;
}
