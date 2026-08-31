import { localeFromBrowser } from './i18n.config';
// Los catálogos viven en public/: es lo que Angular sirve, y el loader los pide por
// HTTP en /assets/i18n. Dejarlos en src/assets compila igual y da 404 en runtime.
import en from '../../../../public/assets/i18n/en.json';
import es from '../../../../public/assets/i18n/es.json';

/** Aplana `{a: {b: 'x'}}` a `['a.b']` para comparar catálogos clave por clave. */
function keysOf(value: unknown, prefix = ''): string[] {
  if (typeof value !== 'object' || value === null) return [prefix];
  return Object.entries(value).flatMap(([key, child]) =>
    keysOf(child, prefix ? `${prefix}.${key}` : key),
  );
}

describe('i18n', () => {
  it('el idioma inicial sale del navegador cuando lo soportamos', () => {
    vi.spyOn(navigator, 'language', 'get').mockReturnValue('es-CR');
    expect(localeFromBrowser()).toBe('es');
  });

  it('un idioma que no soportamos cae en el fallback, no rompe', () => {
    vi.spyOn(navigator, 'language', 'get').mockReturnValue('pt-BR');
    expect(localeFromBrowser()).toBe('en');
  });

  // Regla 24: los dos idiomas se agregan en el mismo commit. Una clave que exista
  // en uno y falte en el otro se ve como texto en el idioma equivocado, no como error.
  it('en y es tienen exactamente las mismas claves', () => {
    expect(keysOf(es).sort()).toEqual(keysOf(en).sort());
  });
});
