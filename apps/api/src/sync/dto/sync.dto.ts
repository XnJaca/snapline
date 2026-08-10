import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsDateString, IsEnum, IsNotEmpty, IsObject, IsOptional, IsString, IsUUID, ValidateNested } from 'class-validator';
import { Permission } from '../../auth/permissions';
import { SiteInputDto } from '../../customers/dto/customer.dto';
import { Customer } from '../../customers/entities/customer.entity';
import { Site } from '../../customers/entities/site.entity';
import { Project } from '../../projects/entities/project.entity';
import { ProjectAssignment } from '../../projects/entities/project-assignment.entity';
import { MediaAsset } from '../../media/entities/media-asset.entity';
import { TimeEntry } from '../../time-entries/entities/time-entry.entity';

export const SYNC_OPERATIONS = [
  'customer.create',
  'customer.update',
  'site.create',
  'project.create',
  'project.update',
  'media.register',
  'timeEntry.clockIn',
  'timeEntry.clockOut',
] as const;
export type SyncOperationType = (typeof SYNC_OPERATIONS)[number];

/**
 * El permiso que exige cada operación, y que el servicio verifica antes de
 * aplicarla.
 *
 * El endpoint entero entra con `time.clock` —el mínimo para que un trabajador
 * empuje su marcaje— pero adentro del lote viajan operaciones que por la puerta
 * REST piden mucho más. Sin esta tabla, un `WORKER` daba de alta clientes y
 * proyectos saltándose `customers.write` y `projects.write` (regla 7).
 */
export const OPERATION_PERMISSION = {
  'customer.create': 'customers.write',
  'customer.update': 'customers.write',
  'site.create': 'customers.write',
  'project.create': 'projects.write',
  'project.update': 'projects.write',
  'media.register': 'media.capture',
  'timeEntry.clockIn': 'time.clock',
  'timeEntry.clockOut': 'time.clock',
} as const satisfies Record<SyncOperationType, Permission>;

/**
 * Payload de `site.create`. Una propiedad no existe suelta, así que de qué
 * cliente cuelga viaja acá — `targetId` es el id de la propiedad misma.
 */
export class SyncSiteCreateDto extends SiteInputDto {
  @IsUUID() customerId!: string;
}

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

  // Tipadas de verdad: con `[Object]` salían al contrato como objeto vacío y el
  // cliente generado las tipaba `dynamic` — parseaba la respuesta, la descartaba
  // entera y no fallaba. Regla 8.
  @ApiProperty({ type: [Customer] }) customers!: Customer[];
  @ApiProperty({ type: [Site] }) sites!: Site[];
  @ApiProperty({ type: [Project] }) projects!: Project[];
  @ApiProperty({ type: [ProjectAssignment] }) assignments!: ProjectAssignment[];
  @ApiProperty({ type: [MediaAsset] }) mediaAssets!: MediaAsset[];
  @ApiProperty({ type: [TimeEntry] }) timeEntries!: TimeEntry[];

  @ApiProperty({
    description: 'Ids borrados desde el cursor, por recurso. Una colección que no aparezca acá deja borrados sin propagar (regla 20).',
    type: 'object',
    additionalProperties: { type: 'array', items: { type: 'string' } },
  })
  deleted!: Record<string, string[]>;
}
