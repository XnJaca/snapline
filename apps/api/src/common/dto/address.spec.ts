import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { AddressDto } from './address.dto';

/**
 * El código de dos letras es de Estados Unidos y Canadá. Exigirlo en todos lados
 * hace imposible cargar una dirección en Costa Rica, donde la provincia es
 * "San José". Ver la ficha de cliente.
 */
describe('AddressDto — el estado según el país', () => {
  const errores = (address: Partial<AddressDto>): string[] => {
    const base = { line1: '1 Calle', city: 'Ciudad', postalCode: '20201' };
    const dto = plainToInstance(AddressDto, { ...base, ...address });
    return validateSync(dto).flatMap((e) => Object.keys(e.constraints ?? {}).map(() => e.property));
  };

  it('Estados Unidos exige dos letras', () => {
    expect(errores({ state: 'MD', country: 'US' })).toEqual([]);
    expect(errores({ state: 'Maryland', country: 'US' })).toContain('state');
  });

  // Sin país explícito el default es US, así que la regla se mantiene.
  it('sin país declarado se asume Estados Unidos', () => {
    expect(errores({ state: 'Maryland' })).toContain('state');
    expect(errores({ state: 'MD' })).toEqual([]);
  });

  it('Canadá también', () => {
    expect(errores({ state: 'ON', country: 'CA' })).toEqual([]);
    expect(errores({ state: 'Ontario', country: 'CA' })).toContain('state');
  });

  it('el resto escribe el nombre de la provincia', () => {
    expect(errores({ state: 'Alajuela', country: 'CR' })).toEqual([]);
    expect(errores({ state: 'Quintana Roo', country: 'MX' })).toEqual([]);
  });

  /**
   * Lo que `@ValidateIf` habría roto: saltea todos los validadores de la
   * propiedad, no solo el del largo, y el estado habría entrado vacío.
   */
  it('sigue siendo obligatorio en todos los países', () => {
    expect(errores({ state: '', country: 'CR' })).toContain('state');
    expect(errores({ state: '   ', country: 'CR' })).toContain('state');
    expect(errores({ state: '', country: 'US' })).toContain('state');
  });
});
