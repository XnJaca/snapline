import { ApiHideProperty } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { TenantEntity } from '../../common/entities/base.entity';
import { AppUser } from '../../auth/entities/app-user.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Project } from '../../projects/entities/project.entity';

// Se revoca, no se borra. El token viaja por SMS: se guarda hasheado.
@Entity('client_access')
export class ClientAccess extends TenantEntity {
  @ManyToOne(() => Customer, { nullable: false })
  @JoinColumn({ name: 'customer_id' })
  customer!: Customer;

  @RelationId((a: ClientAccess) => a.customer)
  customerId!: string;

  // Null da acceso a todos los proyectos del cliente.
  @ManyToOne(() => Project, { nullable: true })
  @JoinColumn({ name: 'project_id' })
  project!: Project | null;

  @RelationId((a: ClientAccess) => a.project)
  projectId!: string | null;

  @ApiHideProperty()
  @Column({ type: 'text', name: 'token_hash', select: false })
  tokenHash!: string;

  @Column({ type: 'timestamptz', name: 'expires_at' })
  expiresAt!: Date;

  @Column({ type: 'timestamptz', name: 'last_seen_at', nullable: true })
  lastSeenAt!: Date | null;

  @ManyToOne(() => AppUser, { nullable: true })
  @JoinColumn({ name: 'claimed_user_id' })
  claimedUser!: AppUser | null;

  @RelationId((a: ClientAccess) => a.claimedUser)
  claimedUserId!: string | null;

  @Column({ type: 'timestamptz', name: 'revoked_at', nullable: true })
  revokedAt!: Date | null;
}
