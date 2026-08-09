import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsDateString, IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Min, ValidateNested } from 'class-validator';
import { DocumentLineDto } from './estimate.dto';
import { PaymentMethod } from '../entities/payment.entity';

export class CreateInvoiceDto {
  @IsOptional() @IsUUID() id?: string;
  @IsUUID() customerId!: string;
  @IsOptional() @IsUUID() projectId?: string;
  @IsOptional() @IsDateString() dueAt?: string;
  @IsArray() @ArrayMinSize(1) @ValidateNested({ each: true }) @Type(() => DocumentLineDto)
  lines!: DocumentLineDto[];
}

export class InvoiceFromEstimateDto {
  @IsOptional() @IsDateString() dueAt?: string;
}

export class RecordPaymentDto {
  @IsInt() @Min(1) amountCents!: number;
  @IsEnum(['CHECK', 'CASH', 'ACH', 'CARD', 'ZELLE', 'OTHER']) method!: PaymentMethod;
  @IsDateString() receivedAt!: string;
  @IsOptional() @IsString() reference?: string;
  // Cobrar dos veces por un reintento de red sería el peor bug del módulo.
  @IsOptional() @IsString() @IsNotEmpty() idempotencyKey?: string;
}

export class VoidInvoiceDto {
  @IsString() @IsNotEmpty() reason!: string;
}
