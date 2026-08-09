import { ApiProperty } from '@nestjs/swagger';
import { ERROR_CODES, ErrorCode } from './error-codes';

export class FieldErrorDto {
  @ApiProperty()
  field!: string;

  @ApiProperty()
  message!: string;
}

/** Toda respuesta de error del API tiene esta forma. Ver ADR-0011. */
export class ErrorResponseDto {
  @ApiProperty({ example: 400 })
  statusCode!: number;

  @ApiProperty({
    enum: ERROR_CODES,
    description: 'Código estable. No se traduce: es contra lo que ramifica el cliente.',
  })
  code!: ErrorCode;

  @ApiProperty({ description: 'Texto para mostrar. Esto sí se traduce.' })
  message!: string;

  @ApiProperty({ type: [FieldErrorDto], description: 'Vacío cuando no aplica; nunca ausente.' })
  details!: FieldErrorDto[];

  @ApiProperty()
  path!: string;

  @ApiProperty({ format: 'date-time' })
  timestamp!: string;
}
