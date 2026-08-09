import { Column, Entity } from 'typeorm';
import { BaseEntity } from '../../common/entities/base.entity';

@Entity('company')
export class Company extends BaseEntity {
  @Column({ type: 'text' })
  name!: string;

  @Column({ type: 'text', name: 'legal_name', nullable: true })
  legalName!: string | null;

  // Los reportes de horas se calculan contra esta zona, nunca la del navegador.
  @Column({ type: 'text', default: 'America/New_York' })
  timezone!: string;

  @Column({ type: 'char', length: 3, default: 'USD' })
  currency!: string;

  @Column({ type: 'jsonb', nullable: true })
  address!: Record<string, unknown> | null;

  @Column({ type: 'uuid', name: 'logo_asset_id', nullable: true })
  logoAssetId!: string | null;

  // Único global, no por empresa.
  @Column({ type: 'citext', name: 'public_site_slug', nullable: true })
  publicSiteSlug!: string | null;

  @Column({ type: 'jsonb', default: {} })
  settings!: Record<string, unknown>;

  @Column({ type: 'timestamptz', name: 'deleted_at', nullable: true })
  deletedAt!: Date | null;
}
