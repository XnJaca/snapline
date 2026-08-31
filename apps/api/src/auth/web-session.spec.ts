import { Request } from 'express';
import {
  clearedRefreshCookie,
  cookieSecure,
  readRefreshCookie,
  refreshCookie,
  REFRESH_COOKIE_MAX_AGE_SECONDS,
} from './web-session';

/**
 * La cookie es el contrato de ADR-0014: si pierde un atributo deja de proteger
 * lo que la decisión fue a proteger, y eso no se nota mirando la pantalla.
 */
describe('cookie de sesión del panel', () => {
  const req = (cookie?: string) => ({ headers: cookie ? { cookie } : {} }) as Request;

  it('lleva los cinco atributos, y el Path incluye el prefijo del API', () => {
    const header = refreshCookie('jwt.abc', REFRESH_COOKIE_MAX_AGE_SECONDS, true);

    expect(header).toBe(
      'sl_refresh=jwt.abc; HttpOnly; Secure; SameSite=Strict; Path=/api/auth/web; Max-Age=2592000',
    );
  });

  it('vive los mismos 30 días que el refresh JWT', () => {
    expect(REFRESH_COOKIE_MAX_AGE_SECONDS).toBe(2592000);
  });

  it('la que borra conserva los atributos y vence ya', () => {
    expect(clearedRefreshCookie(true)).toBe(
      'sl_refresh=; HttpOnly; Secure; SameSite=Strict; Path=/api/auth/web; Max-Age=0',
    );
  });

  // Olvidarse de configurar la variable tiene que dar la cookie segura.
  it('Secure es true salvo que se apague explícitamente', () => {
    expect(cookieSecure({})).toBe(true);
    expect(cookieSecure({ SESSION_COOKIE_SECURE: 'true' })).toBe(true);
    expect(cookieSecure({ SESSION_COOKIE_SECURE: '' })).toBe(true);
    expect(cookieSecure({ SESSION_COOKIE_SECURE: 'false' })).toBe(false);
  });

  it('lee la cookie aunque venga entre otras', () => {
    expect(readRefreshCookie(req('sl.theme=dark; sl_refresh=jwt.abc; otra=1'))).toBe('jwt.abc');
  });

  it('sin cookie, o con la del logout ya aplicada, no hay sesión', () => {
    expect(readRefreshCookie(req())).toBeNull();
    expect(readRefreshCookie(req('otra=1'))).toBeNull();
    expect(readRefreshCookie(req('sl_refresh='))).toBeNull();
  });

  // Un prefijo que termina igual no es la cookie: `x_sl_refresh` no la sustituye.
  it('no confunde una cookie de nombre parecido', () => {
    expect(readRefreshCookie(req('x_sl_refresh=ajeno'))).toBeNull();
  });
});
