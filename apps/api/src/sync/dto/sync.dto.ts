import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsDateString, IsEnum, IsNotEmpty, IsObject, IsOptional, IsString, IsUUID, ValidateNested } from 'class-validator';

export const SYNC_OPERATIONS = [
  'customer.create',
  'project.create',
  'media.register',
  'timeEntry.clockIn',
  'timeEntry.clockOut',
] as const;
export type SyncOperationType = (typeof SYNC_OPERATIONS)[number];

export class SyncOperationDto {
  /** UUIDv7 generado en el dispositivo. Es la clave de idempotencia del lote. */
  @IsUUID() clientId!: string;

  @IsEnum(SYNC_OPERATIONS) type!: SyncOperationType;

  /** Sobre qué registro opera. En los `create` coincide con el id del recurso. */
  @IsUUID() targetId!: string;

  @IsObject() payload!: Record<string, unknown>;

  /** Cuándo lo hizo el usuario. Ordena el lote y viaja como device_recorded_at. */
  @IsDateString() occurredAt!: string;
}

export class SyncPushDto {
  // Tope alto pero finito: una jornada sin señal son decenas, no miles.
  @IsArray() @ArrayMaxSize(500) @ValidateNested({ each: true }) @Type(() => SyncOperationDto)
  operations!: SyncOperationDto[];
}

export class SyncResultDto {
  @ApiProperty({ format: 'uuid' }) clientId!: string;

  @ApiProperty({
    enum: ['applied', 'duplicate', 'failed'],
    description: '`duplicate` es éxito: la operación ya se había aplicado en un intento anterior.',
  })
  status!: 'applied' | 'duplicate' | 'failed';

  @ApiProperty({ nullable: true, type: String }) resourceId!: string | null;
  @ApiProperty({ nullable: true, type: String }) code!: string | null;
  @ApiProperty({ nullable: true, type: String }) message!: string | null;
}

export class SyncPushResponseDto {
  @ApiProperty({ type: [SyncResultDto] }) results!: SyncResultDto[];
  @ApiProperty({ description: 'Cuántas fallaron. Si es 0, la bandeja se puede vaciar entera.' })
  failed!: number;
}

export class SyncPullQueryDto {
  /** Cursor: `updated_at` del último registro traído. Sin él, trae todo. */
  @IsOptional() @IsDateString() since?: string;
}

export class SyncPullResponseDto {
  @ApiProperty({
    format: 'date-time',
    description: 'Cursor para el próximo pull. Lo da el servidor: el reloj del dispositivo no es confiable.',
  })
  serverTime!: string;

  @ApiProperty({ type: [Object] }) customers!: unknown[];
  @ApiProperty({ type: [Object] }) sites!: unknown[];
  @ApiProperty({ type: [Object] }) projects!: unknown[];
  @ApiProperty({ type: [Object] }) assignments!: unknown[];
  @ApiProperty({ type: [Object] }) mediaAssets!: unknown[];
  @ApiProperty({ type: [Object] }) timeEntries!: unknown[];

  @ApiProperty({ description: 'Ids borrados desde el cursor, por recurso.' })
  deleted!: Record<string, string[]>;
}
