import { Request } from 'express';

export const REFRESH_COOKIE = 'sl_refresh';

/**
 * Lleva el prefijo global del API adentro: una cookie solo viaja a las rutas que
 * cuelgan de su `Path`, y las tres del panel están bajo `/api`.
 */
export const REFRESH_COOKIE_PATH = '/api/auth/web';

/** Los mismos 30 días que vive el refresh JWT (ADR-0014 §1). */
export const REFRESH_COOKIE_MAX_AGE_SECONDS = 30 * 24 * 60 * 60;

/**
 * El default es `true` y la excepción se declara: olvidarse de configurarla
 * produce la cookie segura, no la insegura.
 */
export function cookieSecure(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.SESSION_COOKIE_SECURE !== 'false';
}

export function refreshCookie(value: string, maxAgeSeconds: number, secure: boolean): string {
  return [
    `${REFRESH_COOKIE}=${value}`,
    'HttpOnly',
    ...(secure ? ['Secure'] : []),
    'SameSite=Strict',
    `Path=${REFRESH_COOKIE_PATH}`,
    `Max-Age=${maxAgeSeconds}`,
  ].join('; ');
}

/** La cookie que borra: mismos atributos, vida cero. */
export function clearedRefreshCookie(secure: boolean): string {
  return refreshCookie('', 0, secure);
}

export function readRefreshCookie(req: Request): string | null {
  const header = req.headers.cookie;
  if (!header) return null;

  for (const part of header.split(';')) {
    const eq = part.indexOf('=');
    if (eq < 0) continue;
    if (part.slice(0, eq).trim() !== REFRESH_COOKIE) continue;
    const value = decodeURIComponent(part.slice(eq + 1).trim());
    return value === '' ? null : value;
  }
  return null;
}
