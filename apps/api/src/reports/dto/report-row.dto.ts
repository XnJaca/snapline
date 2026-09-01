import { ApiProperty } from '@nestjs/swagger';

/**
 * Lo que devuelven los reportes también es contrato (regla 8). Declarado como
 * DTO y no como interfaz suelta en el `.service.ts`: de ahí el plugin no lee
 * nada y el cliente generado lo tipa como `dynamic`.
 */
export class TimesheetRowDto {
  @ApiProperty({ format: 'uuid' })
  membershipId!: string;

  @ApiProperty()
  workerName!: string;

  @ApiProperty({ format: 'uuid' })
  projectId!: string;

  @ApiProperty()
  projectName!: string;

  @ApiProperty({ description: 'Cuántos registros de tiempo se sumaron' })
  entries!: number;

  @ApiProperty()
  hours!: number;

  @ApiProperty({ nullable: true, type: Number, description: 'La tarifa congelada al aprobar, no la vigente' })
  payRateCents!: number | null;

  @ApiProperty({ nullable: true, type: Number })
  grossCents!: number | null;

  @ApiProperty({ description: 'Registros con bandera: fuera de geocerca, GPS falso, sin señal' })
  flagged!: number;
}

export class JobCostRowDto {
  @ApiProperty({ format: 'uuid' })
  projectId!: string;

  @ApiProperty()
  projectName!: string;

  @ApiProperty()
  laborCents!: number;

  @ApiProperty()
  hours!: number;

  @ApiProperty()
  invoicedCents!: number;

  @ApiProperty()
  estimatedCents!: number;
}
