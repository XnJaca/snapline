import { Type } from 'class-transformer';
import { IsEnum, IsEmail, IsNotEmpty, IsNumber, IsObject, IsOptional, IsPositive, IsString, IsUUID, Max, Min, ValidateNested } from 'class-validator';
import { CustomerSource } from '../entities/customer.entity';
import { AddressDto } from '../../common/dto/address.dto';

export class SiteInputDto {
  @IsOptional() @IsUUID() id?: string;
  @ValidateNested() @Type(() => AddressDto) address!: AddressDto;
  @IsOptional() @IsNumber() @Min(-90) @Max(90) lat?: number;
  @IsOptional() @IsNumber() @Min(-180) @Max(180) lng?: number;
  @IsOptional() @IsNumber() @IsPositive() geofenceRadiusM?: number;
}

/**
 * Corregir una propiedad. `customerId` no está: una propiedad no cambia de
 * cliente — sería otra propiedad.
 */
export class UpdateSiteDto {
  @IsOptional() @ValidateNested() @Type(() => AddressDto) address?: AddressDto;
  @IsOptional() @IsNumber() @Min(-90) @Max(90) lat?: number;
  @IsOptional() @IsNumber() @Min(-180) @Max(180) lng?: number;
  @IsOptional() @IsNumber() @IsPositive() geofenceRadiusM?: number;
}

export class CreateCustomerDto {
  // El id lo genera el cliente (UUIDv7) para poder crear offline.
  @IsOptional() @IsUUID() id?: string;
  @IsString() @IsNotEmpty() displayName!: string;
  @IsOptional() @IsString() firstName?: string;
  @IsOptional() @IsString() lastName?: string;
  @IsOptional() @IsString() companyName?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @ValidateNested() @Type(() => AddressDto) billingAddress?: AddressDto;
  @IsOptional() @IsEnum(['REFERRAL', 'WEB', 'SOCIAL', 'REPEAT', 'OTHER']) source?: CustomerSource;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @ValidateNested() @Type(() => SiteInputDto) site?: SiteInputDto;
}

export class UpdateCustomerDto extends CreateCustomerDto {}
