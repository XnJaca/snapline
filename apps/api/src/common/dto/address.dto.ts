import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty, IsOptional, IsString, Length, Validate,
  ValidationArguments, ValidatorConstraint, ValidatorConstraintInterface,
} from 'class-validator';

/**
 * La misma forma para `customer.billing_address` y `site.address`. Ver la ficha
 * de dominio de cliente.
 *
 * Existe como DTO y no como `jsonb` suelto porque un campo sin forma declarada
 * sale al contrato como objeto vacío, y el cliente generado lo tipa `dynamic`:
 * parsea la dirección, la descarta y no falla. Regla 8 y ADR-0007.
 */
/**
 * Los que usan código de subdivisión de dos letras (ISO 3166-2). En el resto la
 * provincia se escribe con su nombre: "San José", "Alajuela". Ver la ficha de
 * cliente, que es la fuente.
 *
 * Está también en `apps/web/src/app/core/i18n/supported-countries.ts`: son dos
 * códigos y no hay endpoint que los transporte, así que cada lado lo declara
 * citando la misma ficha.
 */
const USES_TWO_LETTER_STATE = ['US', 'CA'];

function usesTwoLetterState(country: string | undefined): boolean {
  return USES_TWO_LETTER_STATE.includes(country ?? 'US');
}

/**
 * Obligatorio en todos lados; de dos letras solo donde corresponde.
 *
 * No se usa `@ValidateIf` porque salta **todos** los validadores de la
 * propiedad, no solo el del largo: con Costa Rica el estado habría quedado sin
 * validar y podría llegar vacío.
 */
@ValidatorConstraint({ name: 'stateForCountry' })
export class StateForCountry implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments): boolean {
    if (typeof value !== 'string' || !value.trim()) return false;
    const { country } = args.object as AddressDto;
    return usesTwoLetterState(country) ? value.trim().length === 2 : true;
  }

  defaultMessage(args: ValidationArguments): string {
    const { country } = args.object as AddressDto;
    return usesTwoLetterState(country)
      ? 'state must be a two-letter code, like MD'
      : 'state is required';
  }
}

export class AddressDto {
  @ApiProperty({ example: '412 Ellsworth Dr' })
  @IsString()
  @IsNotEmpty()
  line1!: string;

  @ApiPropertyOptional({ example: 'Apt 3', description: 'Unidad, suite, piso.' })
  @IsOptional()
  @IsString()
  line2?: string;

  @ApiProperty({ example: 'Silver Spring' })
  @IsString()
  @IsNotEmpty()
  city!: string;

  @ApiProperty({
    example: 'MD',
    description:
      'En Estados Unidos y Canadá, el código de dos letras. En el resto, el ' +
      'nombre de la provincia: "San José".',
  })
  @Validate(StateForCountry)
  state!: string;

  @ApiProperty({ example: '20910' })
  @IsString()
  @IsNotEmpty()
  postalCode!: string;

  @ApiProperty({
    example: 'US',
    default: 'US',
    description:
      'ISO de dos letras. Está desde el principio por la misma razón que la ' +
      'moneda no se concatena a mano: sale gratis hoy y es caro después.',
  })
  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;
}
