import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import { ClientStage } from '../../projects/entities/project.entity';

export class GrantAccessDto {
  @IsUUID() customerId!: string;
  /** Null da acceso a todos los proyectos del cliente. */
  @IsOptional() @IsUUID() projectId?: string;
  @IsOptional() @IsInt() @Min(1) @Max(365) expiresInDays?: number;
}

export class GrantAccessResultDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ description: 'Se muestra una sola vez: en la base solo queda su hash.' })
  token!: string;

  @ApiProperty({ description: 'Link listo para mandar por SMS o email.' })
  url!: string;

  @ApiProperty({ format: 'date-time' })
  expiresAt!: string;
}

export class ClientPhotoDto {
  @ApiProperty({ format: 'uuid' }) id!: string;
  @ApiProperty() url!: string;
  @ApiProperty({ nullable: true, type: String }) capturedAt!: string | null;
}

export class ClientUpdateDto {
  @ApiProperty({ format: 'uuid' }) id!: string;
  @ApiProperty() body!: string;
  @ApiProperty() publishedAt!: string;
  @ApiProperty({ type: [ClientPhotoDto] }) photos!: ClientPhotoDto[];
}

export class ClientOfferDto {
  @ApiProperty({ format: 'uuid' }) id!: string;
  @ApiProperty() title!: string;
  @ApiProperty({ nullable: true, type: String }) pitch!: string | null;
}

/** Lo que ve el cliente final. Nunca incluye costos, horas ni nada interno. */
export class ClientProjectViewDto {
  @ApiProperty({ format: 'uuid' }) id!: string;
  @ApiProperty() name!: string;
  @ApiProperty({ enum: ['INICIO', 'EN_PROCESO', 'FINALIZADO'] }) stage!: ClientStage;

  @ApiProperty({
    enum: ['STAGES', 'PROGRESS'],
    description: 'En STAGES el cliente solo ve la etapa; updates y fotos vienen vacíos.',
  })
  visibilityMode!: string;

  @ApiProperty({ type: [ClientUpdateDto] }) updates!: ClientUpdateDto[];
  @ApiProperty({ type: [ClientPhotoDto] }) photos!: ClientPhotoDto[];
  @ApiProperty({ type: [ClientOfferDto] }) offers!: ClientOfferDto[];
}

export class RequestOfferDto {
  @IsUUID() offerId!: string;
  @IsOptional() @IsString() notes?: string;
}
