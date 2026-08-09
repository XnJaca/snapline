import { Column, CreateDateColumn, PrimaryColumn, UpdateDateColumn } from 'typeorm';
import { v7 as uuidv7 } from 'uuid';

// El id no tiene default en la base: lo genera el cliente con UUIDv7 para poder
// crear registros offline con su id definitivo. Nunca uuid v4.
export abstract class BaseEntity {
  @PrimaryColumn({ type: 'uuid' })
  id!: string;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt!: Date;
}

export abstract class TenantEntity extends BaseEntity {
  @Column({ type: 'uuid', name: 'company_id' })
  companyId!: string;
}

export abstract class SoftDeletableTenantEntity extends TenantEntity {
  @Column({ type: 'timestamptz', name: 'deleted_at', nullable: true })
  deletedAt!: Date | null;
}

export function newId(): string {
  return uuidv7();
}
