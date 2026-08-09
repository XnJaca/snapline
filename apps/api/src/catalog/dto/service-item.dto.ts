import { IsBoolean, IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { ServiceUnit } from '../entities/service-item.entity';

const UNITS = ['HOUR', 'SQFT', 'LINEAR_FT', 'EACH', 'JOB'] as const;

export class CreateServiceItemDto {
  @IsOptional() @IsUUID() id?: string;
  @IsOptional() @IsString() code?: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsOptional() @IsString() description?: string;
  @IsEnum(UNITS) unit!: ServiceUnit;
  @IsInt() @Min(0) unitPriceCents!: number;
  @IsOptional() @IsInt() @Min(0) costCents?: number;
  @IsOptional() @IsBoolean() taxable?: boolean;
  @IsOptional() @IsString() category?: string;
}

export class UpdateServiceItemDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() @IsNotEmpty() name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsEnum(UNITS) unit?: ServiceUnit;
  @IsOptional() @IsInt() @Min(0) unitPriceCents?: number;
  @IsOptional() @IsInt() @Min(0) costCents?: number;
  @IsOptional() @IsBoolean() taxable?: boolean;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsBoolean() active?: boolean;
}
