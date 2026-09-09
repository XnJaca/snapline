import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail, IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Min, MinLength,
} from 'class-validator';
import { EmploymentType, MembershipRole, MembershipStatus } from '../../auth/entities/membership.entity';
import { Locale } from '../../auth/entities/app-user.entity';

const ROLES = ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'] as const;
const EMPLOYMENT = ['W2', 'CONTRACTOR_1099'] as const;
const LOCALES = ['en', 'es'] as const;

export class CreateMemberDto {
  @IsOptional() @IsUUID() id?: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() @IsNotEmpty() phone?: string;
  @IsEnum(ROLES) role!: MembershipRole;
  @IsOptional() @IsInt() @Min(0) payRateCents?: number;
  @IsOptional() @IsEnum(EMPLOYMENT) employmentType?: EmploymentType;
  @IsOptional() @IsEnum(LOCALES) locale?: Locale;
}

export class UpdateMemberDto {
  @IsOptional() @IsEnum(ROLES) role?: MembershipRole;
  @IsOptional() @IsInt() @Min(0) payRateCents?: number;
  @IsOptional() @IsEnum(EMPLOYMENT) employmentType?: EmploymentType;

  // Del usuario, no de la membresía: un teléfono mal tecleado deja a esa persona
  // sin poder entrar, y sin esto la única salida sería borrarla y recrearla.
  @IsOptional() @IsString() @IsNotEmpty() name?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() phone?: string;
}

export class VerifyInviteDto {
  /** Falso cuando esa persona ya trabaja para otra empresa y tiene contraseña. */
  @ApiProperty() needsPassword!: boolean;
  @ApiProperty() expiresAt!: Date;
}

export class CheckInviteDto {
  @IsString() @IsNotEmpty() identifier!: string;
  @IsString() @IsNotEmpty() code!: string;
}

export class RedeemInviteDto {
  // Email o teléfono, igual que el login: muchos trabajadores no usan email.
  @IsString() @IsNotEmpty() identifier!: string;
  @IsString() @IsNotEmpty() code!: string;

  // Opcional porque quien ya trabaja para otro contratista conserva la suya: el
  // cuerpo tiene forma fija y es el servidor el que decide si la usa.
  @IsOptional() @IsString() @MinLength(8) password?: string;
}

export class MemberCrewDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
}

export class MemberDto {
  @ApiProperty() id!: string;
  @ApiProperty() userId!: string;
  @ApiProperty() name!: string;
  @ApiPropertyOptional({ nullable: true }) email!: string | null;
  @ApiPropertyOptional({ nullable: true }) phone!: string | null;
  @ApiProperty({ enum: LOCALES }) locale!: Locale;
  @ApiProperty({ enum: ROLES }) role!: MembershipRole;
  @ApiProperty({ enum: ['INVITED', 'ACTIVE', 'INACTIVE'] }) status!: MembershipStatus;

  // Solo sale por acá. La entity lo lleva con select: false porque viaja embebida
  // en cuadrillas y asignaciones que ven FOREMAN y WORKER.
  @ApiPropertyOptional({ nullable: true }) payRateCents!: number | null;
  @ApiPropertyOptional({ enum: EMPLOYMENT, nullable: true }) employmentType!: EmploymentType | null;

  @ApiPropertyOptional({ nullable: true }) invitedAt!: Date | null;
  @ApiPropertyOptional({ nullable: true }) joinedAt!: Date | null;
  @ApiPropertyOptional({ nullable: true }) inviteExpiresAt!: Date | null;
  @ApiPropertyOptional({ type: MemberCrewDto, nullable: true }) crew!: MemberCrewDto | null;
}

/** El código en claro viaja una sola vez: en la respuesta que lo emite. */
export class MemberWithInviteDto extends MemberDto {
  @ApiProperty() inviteCode!: string;
}
