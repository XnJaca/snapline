import { IsArray, IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';
import { ClientVisibilityMode, ProjectStatus } from '../entities/project.entity';

const STATUSES = ['LEAD', 'ESTIMATED', 'SCHEDULED', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED'] as const;

export class CreateProjectDto {
  @IsOptional() @IsUUID() id?: string;
  @IsUUID() customerId!: string;
  @IsUUID() siteId!: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() serviceType?: string;
  @IsOptional() @IsEnum(STATUSES) status?: ProjectStatus;
  @IsOptional() @IsEnum(['STAGES', 'PROGRESS']) clientVisibilityMode?: ClientVisibilityMode;
  @IsOptional() @IsDateString() startDate?: string;
  @IsOptional() @IsDateString() targetEndDate?: string;
}

export class UpdateProjectDto {
  @IsOptional() @IsString() @IsNotEmpty() name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() serviceType?: string;
  @IsOptional() @IsEnum(STATUSES) status?: ProjectStatus;
  @IsOptional() @IsEnum(['STAGES', 'PROGRESS']) clientVisibilityMode?: ClientVisibilityMode;
  @IsOptional() @IsDateString() startDate?: string;
  @IsOptional() @IsDateString() targetEndDate?: string;
  @IsOptional() @IsDateString() actualEndDate?: string;
}

export class AssignCrewDto {
  @IsOptional() @IsUUID() crewId?: string;
  @IsOptional() @IsUUID() membershipId?: string;
  @IsDateString() workDate!: string;
  @IsOptional() plannedHeadcount?: number;
}

/**
 * Una nota de la bitácora de la obra.
 *
 * `visibility` no acepta `PUBLIC`: publicar al portafolio es otro acto, con su
 * propia puerta y el gate del EXIF. La base lo rechaza además con un CHECK.
 */
export class CreateProjectUpdateDto {
  @IsOptional() @IsUUID() id?: string;
  @IsString() @IsNotEmpty() body!: string;
  @IsOptional() @IsEnum(['INTERNAL', 'CLIENT']) visibility?: 'INTERNAL' | 'CLIENT';
  @IsOptional() @IsArray() @IsUUID('all', { each: true }) assetIds?: string[];
}
