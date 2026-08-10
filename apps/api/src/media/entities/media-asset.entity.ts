import { ApiPropertyOptional } from '@nestjs/swagger';
import { Column, Entity, JoinColumn, ManyToOne, RelationId } from 'typeorm';
import { SoftDeletableTenantEntity } from '../../common/entities/base.entity';
import { Membership } from '../../auth/entities/membership.entity';
import { Project } from '../../projects/entities/project.entity';

export type MediaKind = 'PHOTO' | 'VIDEO' | 'DOCUMENT';
export type MediaVisibility = 'INTERNAL' | 'CLIENT' | 'PUBLIC';
export type UploadStatus = 'PENDING' | 'UPLOADING' | 'READY' | 'FAILED';
export type DocumentKind =
  | 'CONTRACT' | 'PERMIT' | 'BLUEPRINT' | 'INSURANCE' | 'W9' | 'RECEIPT'
  | 'PHOTO_RELEASE' | 'SIGNATURE' | 'OTHER';

const numeric = {
  to: (v: number | null) => v,
  from: (v: string | null) => (v === null ? null : Number(v)),
};

@Entity('media_asset')
export class MediaAsset extends SoftDeletableTenantEntity {
  @ApiPropertyOptional()
  @ManyToOne(() => Project, { nullable: false })
  @JoinColumn({ name: 'project_id' })
  project!: Project;

  @RelationId((a: MediaAsset) => a.project)
  projectId!: string;

  @Column({ type: 'enum', enum: ['PHOTO', 'VIDEO', 'DOCUMENT'], enumName: 'media_kind' })
  kind!: MediaKind;

  @Column({ type: 'enum', enum: ['CONTRACT', 'PERMIT', 'BLUEPRINT', 'INSURANCE', 'W9', 'RECEIPT', 'PHOTO_RELEASE', 'SIGNATURE', 'OTHER'], enumName: 'document_kind', name: 'document_kind', nullable: true })
  documentKind!: DocumentKind | null;

  @Column({ type: 'text', name: 'storage_key' })
  storageKey!: string;

  @Column({ type: 'text' })
  mime!: string;

  @Column({ type: 'bigint', nullable: true, transformer: numeric })
  bytes!: number | null;

  @Column({ type: 'integer', nullable: true })
  width!: number | null;

  @Column({ type: 'integer', nullable: true })
  height!: number | null;

  // Del EXIF, no de la subida: con offline la diferencia puede ser de días.
  @Column({ type: 'timestamptz', name: 'captured_at', nullable: true })
  capturedAt!: Date | null;

  @ApiPropertyOptional()
  @ManyToOne(() => Membership, { nullable: true })
  @JoinColumn({ name: 'uploaded_by_membership_id' })
  uploadedBy!: Membership | null;

  @RelationId((a: MediaAsset) => a.uploadedBy)
  uploadedByMembershipId!: string | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, name: 'device_lat', nullable: true, transformer: numeric })
  deviceLat!: number | null;

  @Column({ type: 'numeric', precision: 9, scale: 6, name: 'device_lng', nullable: true, transformer: numeric })
  deviceLng!: number | null;

  // Desduplica reintentos de subida.
  @Column({ type: 'text' })
  checksum!: string;

  @Column({ type: 'enum', enum: ['PENDING', 'UPLOADING', 'READY', 'FAILED'], enumName: 'upload_status', name: 'upload_status', default: 'PENDING' })
  uploadStatus!: UploadStatus;

  // Escalera INTERNAL -> CLIENT -> PUBLIC. Un trigger rechaza PUBLIC sin photo release.
  @Column({ type: 'enum', enum: ['INTERNAL', 'CLIENT', 'PUBLIC'], enumName: 'media_visibility', default: 'INTERNAL' })
  visibility!: MediaVisibility;

  // Publicar con EXIF expone la dirección exacta de la casa del cliente.
  @Column({ type: 'timestamptz', name: 'exif_stripped_at', nullable: true })
  exifStrippedAt!: Date | null;
}
