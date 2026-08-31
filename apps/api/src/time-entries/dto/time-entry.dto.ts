import { IsBoolean, IsDateString, IsEnum, IsNumber, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import { TimeEntryStatus } from '../entities/time-entry.entity';

export const TIME_ENTRY_STATUSES = ['PENDING', 'APPROVED', 'REJECTED'] as const;

// El dispositivo manda lat/lng crudas. NO manda distancia ni withinGeofence:
// eso lo calcula el servidor (ADR-0003).
export class ClockInDto {
  @IsOptional() @IsUUID() id?: string;
  @IsUUID() projectId!: string;
  @IsOptional() @IsUUID() membershipId?: string;
  @IsDateString() deviceRecordedAt!: string;
  @IsOptional() @IsNumber() @Min(-90) @Max(90) lat?: number;
  @IsOptional() @IsNumber() @Min(-180) @Max(180) lng?: number;
  @IsOptional() @IsNumber() accuracyM?: number;
  @IsOptional() @IsUUID() photoId?: string;
  @IsOptional() @IsString() deviceId?: string;
  @IsOptional() @IsBoolean() isMockLocation?: boolean;
  @IsOptional() @IsBoolean() recordedOffline?: boolean;
}

export class ClockOutDto {
  @IsDateString() deviceRecordedAt!: string;
  @IsOptional() @IsNumber() @Min(-90) @Max(90) lat?: number;
  @IsOptional() @IsNumber() @Min(-180) @Max(180) lng?: number;
  @IsOptional() @IsNumber() accuracyM?: number;
  @IsOptional() @IsUUID() photoId?: string;
  @IsOptional() @IsNumber() @Min(0) breakMinutes?: number;
  @IsOptional() @IsBoolean() isMockLocation?: boolean;
}

export class ApproveDto {
  @IsOptional() @IsString() reason?: string;

  // El estado que la jornada tenía cuando se decidió. Lo manda el móvil, que
  // pudo decidir sin señal sobre un estado que ya cambió; la web es online y lo
  // omite. Si viene y no coincide con el actual, la decisión no se aplica.
  @IsOptional() @IsEnum(TIME_ENTRY_STATUSES) expectedStatus?: TimeEntryStatus;
}
