/**
 * Normaliza a E.164 para comparar. "301-555-0142", "(301) 555 0142" y
 * "+13015550142" son el mismo número y tres strings distintos; muchos
 * trabajadores solo tienen teléfono, así que la comparación cruda los deja
 * afuera del login. Ver DEBT-0003.
 *
 * Asume país por defecto US: el design partner opera en Maryland. Cuando haya
 * usuarios fuera, el país sale de la empresa y esto necesita el prefijo explícito.
 */
const DEFAULT_COUNTRY_CODE = '1';

export function isPhoneLike(value: string): boolean {
  return /^[+(\d][\d\s\-().]*$/.test(value) && (value.match(/\d/g)?.length ?? 0) >= 7;
}

export function normalizePhone(raw: string): string | null {
  const value = raw.trim();
  if (!isPhoneLike(value)) return null;

  const digits = value.replace(/\D/g, '');
  if (!digits) return null;

  if (value.startsWith('+')) return `+${digits}`;
  if (digits.length === 10) return `+${DEFAULT_COUNTRY_CODE}${digits}`;
  if (digits.length === 11 && digits.startsWith(DEFAULT_COUNTRY_CODE)) return `+${digits}`;
  return `+${digits}`;
}

/** Devuelve el identificador listo para comparar contra la base. */
export function normalizeIdentifier(raw: string): { email: string | null; phone: string | null } {
  const value = raw.trim();
  if (value.includes('@')) return { email: value.toLowerCase(), phone: null };
  return { email: null, phone: normalizePhone(value) };
}
