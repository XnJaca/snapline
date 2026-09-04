import { FormControl } from '@angular/forms';
import { stateValidatorsFor, usesTwoLetterState } from './address-group';

/**
 * El código de dos letras es una regla de Estados Unidos y Canadá, no del
 * formulario. Aplicarla en todos lados hace imposible cargar una dirección en
 * Costa Rica, donde la provincia se llama "San José".
 */
describe('estado o provincia según el país', () => {
  const validar = (iso: string, valor: string) => {
    const control = new FormControl(valor, stateValidatorsFor(iso));
    return control.valid;
  };

  it('Estados Unidos y Canadá piden el código de dos letras', () => {
    expect(usesTwoLetterState('US')).toBe(true);
    expect(usesTwoLetterState('CA')).toBe(true);

    expect(validar('US', 'MD')).toBe(true);
    expect(validar('US', 'Maryland')).toBe(false);
    expect(validar('CA', 'ON')).toBe(true);
  });

  it('el resto escribe el nombre de la provincia', () => {
    expect(usesTwoLetterState('CR')).toBe(false);

    expect(validar('CR', 'San José')).toBe(true);
    expect(validar('MX', 'Quintana Roo')).toBe(true);
    expect(validar('GT', 'Sacatepéquez')).toBe(true);
  });

  it('sigue siendo obligatorio en todos lados', () => {
    expect(validar('US', '')).toBe(false);
    expect(validar('CR', '')).toBe(false);
  });
});
