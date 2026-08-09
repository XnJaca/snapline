import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsDateString, IsInt, IsNotEmpty, IsNumber, IsOptional, IsPositive, IsString, IsUUID, Min, ValidateNested } from 'class-validator';

export class DocumentLineDto {
  // Si viene service_item_id se copian sus valores; si no, la línea es libre.
  @IsOptional() @IsUUID() serviceItemId?: string;
  @IsOptional() @IsString() @IsNotEmpty() name?: string;
  @IsOptional() @IsString() description?: string;
  @IsNumber() @IsPositive() qty!: number;
  @IsOptional() @IsInt() @Min(0) unitPriceCentsOverride?: number;
}

export class CreateEstimateDto {
  @IsOptional() @IsUUID() id?: string;
  @IsUUID() customerId!: string;
  @IsOptional() @IsUUID() projectId?: string;
  @IsOptional() @IsDateString() expiresAt?: string;
  @IsOptional() @IsString() terms?: string;
  @IsArray() @ArrayMinSize(1) @ValidateNested({ each: true }) @Type(() => DocumentLineDto)
  lines!: DocumentLineDto[];
}

export class AcceptEstimateDto {
  @IsOptional() @IsUUID() signatureAssetId?: string;
}
