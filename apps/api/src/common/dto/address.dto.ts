import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Length, MaxLength } from 'class-validator';

/**
 * La misma forma para `customer.billing_address` y `site.address`. Ver la ficha
 * de dominio de cliente.
 *
 * Existe como DTO y no como `jsonb` suelto porque un campo sin forma declarada
 * sale al contrato como objeto vacío, y el cliente generado lo tipa `dynamic`:
 * parsea la dirección, la descarta y no falla. Regla 8 y ADR-0007.
 */
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

  // Dos letras alcanzaban con Estados Unidos y Canadá. La app ofrece dieciséis
  // países: en Costa Rica la provincia es «Alajuela» y en Guatemala el
  // departamento es «Sacatepéquez». El código corto se sigue pudiendo escribir.
  @ApiProperty({ example: 'MD', description: 'Estado, provincia o departamento.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
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
