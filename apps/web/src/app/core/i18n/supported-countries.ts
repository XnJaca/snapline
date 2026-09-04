/**
 * Los países que el panel ofrece para un teléfono o una dirección. Es la misma
 * lista que `apps/mobile/lib/core/i18n/supported_countries.dart`, y por la misma
 * razón: una de 240 obliga a buscar en un selector que se usa en cada alta.
 * Estados Unidos y Canadá primero, que es donde opera el contratista, y después
 * América Latina, de donde vienen sus cuadrillas y buena parte de sus clientes.
 *
 * **Restringir lo que se ofrece no restringe lo que se puede guardar.** Un número
 * o una dirección ya cargados de otro país se muestran igual.
 *
 * El nombre no está acá: lo resuelve `Intl.DisplayNames` en el idioma activo, así
 * que no hay 22 cadenas por idioma que mantener.
 */
export interface Country {
  readonly iso: string;
  /** Sin el `+`. Varios comparten el 1: es el plan de numeración de Norteamérica. */
  readonly dial: string;
}

const FAVORITES: Country[] = [
  { iso: 'US', dial: '1' },
  { iso: 'CA', dial: '1' },
];

const LATIN_AMERICA: Country[] = [
  { iso: 'MX', dial: '52' },
  { iso: 'GT', dial: '502' },
  { iso: 'SV', dial: '503' },
  { iso: 'HN', dial: '504' },
  { iso: 'NI', dial: '505' },
  { iso: 'CR', dial: '506' },
  { iso: 'PA', dial: '507' },
  { iso: 'CU', dial: '53' },
  { iso: 'DO', dial: '1' },
  { iso: 'PR', dial: '1' },
  { iso: 'CO', dial: '57' },
  { iso: 'VE', dial: '58' },
  { iso: 'EC', dial: '593' },
  { iso: 'PE', dial: '51' },
  { iso: 'BO', dial: '591' },
  { iso: 'PY', dial: '595' },
  { iso: 'UY', dial: '598' },
  { iso: 'AR', dial: '54' },
  { iso: 'CL', dial: '56' },
  { iso: 'BR', dial: '55' },
];

export const COUNTRIES: readonly Country[] = [...FAVORITES, ...LATIN_AMERICA];

/**
 * Los que usan código de subdivisión de dos letras (ISO 3166-2). En el resto la
 * provincia se escribe con su nombre: "San José", "Alajuela".
 */
export const USES_TWO_LETTER_STATE: readonly string[] = ['US', 'CA'];

/** Con el que arranca un alta: Maryland es `+1`. */
export const DEFAULT_COUNTRY = 'US';

export function dialOf(iso: string): string {
  return COUNTRIES.find((c) => c.iso === iso)?.dial ?? '1';
}

/**
 * Arma el E.164 con lo que el formulario tiene. No valida largo por país —eso es
 * lo que [[DEBT-0003]] sigue cubriendo—: normaliza para que la misma persona no
 * entre dos veces con dos formatos.
 */
export function toE164(iso: string, numero: string): string | null {
  const digitos = numero.replace(/\D/g, '');
  if (!digitos) return null;
  return `+${dialOf(iso)}${digitos}`;
}

/** Separa un E.164 guardado en país y número, para poder editarlo. */
export function fromE164(e164: string | null | undefined): { iso: string; numero: string } {
  if (!e164?.startsWith('+')) return { iso: DEFAULT_COUNTRY, numero: e164 ?? '' };

  const sinMas = e164.slice(1);
  // Del más largo al más corto: 1 es prefijo de 1, pero 5 lo es de 502.
  const candidatos = [...COUNTRIES].sort((a, b) => b.dial.length - a.dial.length);
  const país = candidatos.find((c) => sinMas.startsWith(c.dial));
  if (!país) return { iso: DEFAULT_COUNTRY, numero: sinMas };

  return { iso: país.iso, numero: sinMas.slice(país.dial.length) };
}
