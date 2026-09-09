import { ApiPropertyOptional } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Crew } from '../../crews/entities/crew.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Project } from './project.entity';

// Va cuadrilla o persona, nunca las dos. La base lo obliga.
@Entity('project_assignment')
export class ProjectAssignment extends SoftDeletableTenantEntity {
  @ApiPropertyOptional()
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((a: ProjectAssignment) => a.project)
  projectId!: string;

  @ApiPropertyOptional()
  @ManyToOne(() => Crew, { nullable: true })
  @JoinColumn({ name: 'crew_id' })
  crew!: Crew | null;

  @RelationId((a: ProjectAssignment) => a.crew)
  crewId!: string | null;

  @ApiPropertyOptional()
  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'membership_id' })
  membership!: Membership | null;

  @RelationId((a: ProjectAssignment) => a.membership)
  membershipId!: string | null;

  @Column({ type: 'date', name: 'from_date' })
  fromDate!: string;

  // Nulo mientras la cuadrilla siga en la obra. Lo cierra una persona: la obra
  // tiene su fecha estimada, pero cuándo terminó esta cuadrilla ahí no se deduce.
  @Column({ type: 'date', name: 'to_date', nullable: true })
  toDate!: string | null;

  @Column({ type: 'integer', name: 'planned_headcount', nullable: true })
  plannedHeadcount!: number | null;
}
