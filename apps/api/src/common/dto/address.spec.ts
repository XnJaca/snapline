import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { AddressDto } from './address.dto';

/**
 * El estado de una dirección salió de `@Length(2, 2)` el 2026-09-03: la app
 * ofrece dieciséis países y fuera de Estados Unidos esto es una provincia o un
 * departamento con nombre entero. Ver `docs/PENDIENTES.md`.
 */
describe('AddressDto.state', () => {
  const base = {
    line1: '250 mts este de la escuela',
    city: 'San Ramón',
    postalCode: '20201',
    country: 'CR',
  };

  const errores = (state: unknown) =>
    validateSync(plainToInstance(AddressDto, { ...base, state }))
      .flatMap((e) => Object.keys(e.constraints ?? {}));

  it('acepta el nombre entero de una provincia', () => {
    expect(errores('Alajuela')).toEqual([]);
  });

  it('acepta un departamento con acentos y espacios', () => {
    expect(errores('Sacatepéquez')).toEqual([]);
    expect(errores('San José')).toEqual([]);
  });

  it('sigue aceptando el código corto de Estados Unidos', () => {
    // Lo que ya estaba cargado no se invalida por relajar la regla.
    expect(errores('MD')).toEqual([]);
  });

  it('no acepta vacío: la dirección sin estado no ubica nada', () => {
    expect(errores('')).toContain('isNotEmpty');
    // `'   '` pasa: `@IsNotEmpty` de class-validator no hace trim. Es un hueco
    // común a todos los campos de texto del API, no de este cambio, y se cierra
    // con un transform global el día que se aborde.
  });

  it('pone un techo, para que no entre un párrafo', () => {
    expect(errores('x'.repeat(101))).toContain('maxLength');
  });
});
