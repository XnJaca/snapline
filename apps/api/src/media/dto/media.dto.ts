import { ApiProperty } from '@nestjs/swagger';
import { ArrayUnique, IsArray, IsDateString, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';
import { MediaAsset, MediaKind, MediaVisibility } from '../entities/media-asset.entity';
import { MEDIA_TAG_KINDS, MediaTagKind } from '../entities/media-tag.entity';

export class RegisterAssetDto {
  @IsOptional() @IsUUID() id?: string;
  @IsUUID() projectId!: string;
  @IsEnum(['PHOTO', 'VIDEO', 'DOCUMENT']) kind!: MediaKind;
  @IsString() @IsNotEmpty() mime!: string;
  // Desduplica reintentos de subida desde el dispositivo.
  @IsString() @IsNotEmpty() checksum!: string;
  @IsOptional() @IsNumber() bytes?: number;
  @IsOptional() @IsNumber() width?: number;
  @IsOptional() @IsNumber() height?: number;
  @IsOptional() @IsDateString() capturedAt?: string;
  @IsOptional() @IsNumber() deviceLat?: number;
  @IsOptional() @IsNumber() deviceLng?: number;
}

export class SetVisibilityDto {
  @IsEnum(['INTERNAL', 'CLIENT', 'PUBLIC']) visibility!: MediaVisibility;
}

/**
 * Reemplaza el conjunto entero de etiquetas, no agrega de a una: quitar una sin
 * señal necesitaría una operación de borrado propagable, y mandar el set
 * completo la vuelve idempotente sin nada extra (regla 19).
 */
export class SetTagsDto {
  // Sin ArrayMaxSize: con el enum acotado y sin repetidos, el tope ya es el
  // largo del enum. Un número suelto ahí solo se desincroniza al agregar una.
  @IsArray()
  @ArrayUnique()
  @IsEnum(MEDIA_TAG_KINDS, { each: true })
  @ApiProperty({ enum: MEDIA_TAG_KINDS, isArray: true })
  tags!: MediaTagKind[];
}

/**
 * El asset con sus etiquetas. Viajan adentro y no como colección propia porque
 * `media_tag` no tiene `updated_at` ni `deleted_at`, de las que depende el pull
 * incremental — ver SPEC-0010.
 */
export class MediaAssetDto extends MediaAsset {
  @ApiProperty({ enum: MEDIA_TAG_KINDS, isArray: true })
  tags!: MediaTagKind[];
}

/**
 * Lo que devuelve registrar un asset. Sin este DTO la respuesta salía al
 * contrato como `{}` y el cliente Dart descartaba la `uploadUrl` sin fallar
 * (regla 8).
 */
export class RegisterAssetResponseDto {
  @ApiProperty({ type: MediaAsset }) asset!: MediaAsset;
  uploadUrl!: string;
  uploadUrlExpiresInSeconds!: number;
}

/** Una URL firmada de vida corta. La misma forma para subir y para descargar. */
export class SignedUrlDto {
  url!: string;
  expiresInSeconds!: number;
}
