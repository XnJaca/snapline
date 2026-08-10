import { ApiProperty } from '@nestjs/swagger';
import { Column, Entity } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { AddressDto } from '../../common/dto/address.dto';

export type CustomerSource = 'REFERRAL' | 'WEB' | 'SOCIAL' | 'REPEAT' | 'OTHER';

@Entity('customer')
export class Customer extends SoftDeletableTenantEntity {
  @Column({ type: 'text', name: 'display_name' })
  displayName!: string;

  @Column({ type: 'text', name: 'first_name', nullable: true })
  firstName!: string | null;

  @Column({ type: 'text', name: 'last_name', nullable: true })
  lastName!: string | null;

  @Column({ type: 'text', name: 'company_name', nullable: true })
  companyName!: string | null;

  @Column({ type: 'citext', nullable: true })
  email!: string | null;

  @Column({ type: 'text', nullable: true })
  phone!: string | null;

  @ApiProperty({ type: AddressDto, nullable: true })
  @Column({ type: 'jsonb', name: 'billing_address', nullable: true })
  billingAddress!: AddressDto | null;

  @Column({ type: 'enum', enum: ['REFERRAL', 'WEB', 'SOCIAL', 'REPEAT', 'OTHER'], enumName: 'customer_source', nullable: true })
  source!: CustomerSource | null;

  @Column({ type: 'text', nullable: true })
  notes!: string | null;

  // Habilita publicar. Un trigger rechaza visibility=PUBLIC sin esto.
  @Column({ type: 'timestamptz', name: 'photo_release_granted_at', nullable: true })
  photoReleaseGrantedAt!: Date | null;

  @Column({ type: 'uuid', name: 'photo_release_document_id', nullable: true })
  photoReleaseDocumentId!: string | null;
}
