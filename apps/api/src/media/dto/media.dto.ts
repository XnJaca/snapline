import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';
import { MediaAsset, MediaKind, MediaVisibility } from '../entities/media-asset.entity';

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
