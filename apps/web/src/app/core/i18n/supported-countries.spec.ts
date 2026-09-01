import { COUNTRIES, fromE164, toE164 } from './supported-countries';

/**
 * El teléfono se normaliza acá porque el DTO no valida formato. Si esto se
 * rompe, la misma persona entra dos veces con dos formatos y nadie se entera.
 */
describe('teléfono en E.164', () => {
  it('arma el número con el prefijo del país', () => {
    expect(toE164('US', '555 123 4567')).toBe('+15551234567');
    expect(toE164('CR', '8888-8888')).toBe('+50688888888');
  });

  it('ignora lo que no es dígito, que es como la gente escribe', () => {
    expect(toE164('US', '(555) 987-6543')).toBe('+15559876543');
  });

  it('un teléfono vacío es nulo, no un prefijo suelto', () => {
    expect(toE164('US', '')).toBeNull();
    expect(toE164('US', '   ')).toBeNull();
  });

  it('vuelve a país y número para poder corregirlo', () => {
    expect(fromE164('+15551234567')).toEqual({ iso: 'US', numero: '5551234567' });
    expect(fromE164('+50688888888')).toEqual({ iso: 'CR', numero: '88888888' });
  });

  // 5 es prefijo de 502: el más largo tiene que ganar o Guatemala se lee como Perú.
  it('elige el prefijo más largo que calce', () => {
    expect(fromE164('+50255551234').iso).toBe('GT');
    expect(fromE164('+51987654321').iso).toBe('PE');
  });

  it('lo que no reconoce no se pierde: queda como número', () => {
    expect(fromE164('+9997654321').numero).toBe('9997654321');
    expect(fromE164(null)).toEqual({ iso: 'US', numero: '' });
  });

  it('ida y vuelta conserva el número', () => {
    for (const country of COUNTRIES) {
      const e164 = toE164(country.iso, '5551234')!;
      expect(toE164(fromE164(e164).iso, fromE164(e164).numero)).toBe(e164);
    }
  });
});
