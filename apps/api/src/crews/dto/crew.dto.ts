import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MembershipRole } from '../../auth/entities/membership.entity';
import { IsDateString, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateCrewDto {
  @IsOptional() @IsUUID() id?: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsOptional() @IsUUID() foremanMembershipId?: string;
  @IsOptional() @IsString() color?: string;
}

export class UpdateCrewDto {
  @IsOptional() @IsString() @IsNotEmpty() name?: string;
  @IsOptional() @IsUUID() foremanMembershipId?: string;
  @IsOptional() @IsString() color?: string;
}

/** Sacar a alguien de la cuadrilla: desde cuándo deja de pertenecer. */
export class EndCrewMemberDto {
  @IsDateString() toDate!: string;
}

export class AddCrewMemberDto {
  @IsUUID() membershipId!: string;
  @IsDateString() fromDate!: string;
  @IsOptional() @IsDateString() toDate?: string;
}

/**
 * El nombre de la persona, y solo el nombre. Extender la relación de la entity
 * hasta `user` —lo que proponía DEBT-0010— arrastraría su correo y su teléfono a
 * una pantalla que ve cualquier FOREMAN.
 */
export class CrewPersonDto {
  @ApiProperty() membershipId!: string;
  @ApiProperty() name!: string;
}

export class CrewDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiPropertyOptional({ nullable: true }) color!: string | null;
  @ApiPropertyOptional({ type: CrewPersonDto, nullable: true }) foreman!: CrewPersonDto | null;
  @ApiProperty() memberCount!: number;
}

export class CrewMemberDto {
  @ApiProperty() id!: string;
  @ApiProperty() membershipId!: string;
  @ApiProperty() name!: string;
  @ApiProperty({ enum: ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'] })
  role!: MembershipRole;
  @ApiProperty() fromDate!: string;
  @ApiPropertyOptional({ nullable: true }) toDate!: string | null;
}

export class CrewAssignmentDto {
  @ApiProperty() id!: string;
  @ApiProperty() projectId!: string;
  @ApiProperty() projectName!: string;
  @ApiProperty() fromDate!: string;
  @ApiPropertyOptional({ nullable: true }) toDate!: string | null;
}
