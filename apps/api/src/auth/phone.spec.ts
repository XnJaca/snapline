import { normalizeIdentifier, normalizePhone } from './phone';

/**
 * DEBT-0003: muchos trabajadores solo tienen teléfono. Comparar el identificador
 * como texto plano los deja afuera del login según cómo lo escriban.
 */
describe('normalizePhone', () => {
  it('el mismo número escrito de varias formas da el mismo E.164', () => {
    const formas = ['+15551234567', '15551234567', '5551234567', '555-123-4567', '(555) 123 4567', '555.123.4567', ' 555 123 4567 '];
    const normalizados = new Set(formas.map(normalizePhone));

    expect([...normalizados]).toEqual(['+15551234567']);
  });

  it('respeta un prefijo internacional explícito', () => {
    expect(normalizePhone('+50688887777')).toBe('+50688887777');
  });

  it('no inventa número con algo que no lo es', () => {
    expect(normalizePhone('william@pcdmv.com')).toBeNull();
    expect(normalizePhone('123')).toBeNull();
    expect(normalizePhone('')).toBeNull();
  });
});

describe('normalizeIdentifier', () => {
  it('distingue email de teléfono', () => {
    expect(normalizeIdentifier('  William@PCDMV.com ')).toEqual({ email: 'william@pcdmv.com', phone: null });
    expect(normalizeIdentifier('(555) 123-4567')).toEqual({ email: null, phone: '+15551234567' });
  });

  it('el email se compara en minúsculas', () => {
    expect(normalizeIdentifier('A@B.COM').email).toBe('a@b.com');
  });
});
