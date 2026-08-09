import { IsDateString, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';
import { MediaKind, MediaVisibility } from '../entities/media-asset.entity';

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
