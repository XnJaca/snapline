import { inject } from '@angular/core';
import { HttpErrorResponse, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { catchError, switchMap, throwError } from 'rxjs';
import { API_BASE_URL } from './api.config';
import { SessionService } from '../session/session.service';

/**
 * Adjunta el bearer y, cuando el access vence, refresca y **reintenta la llamada
 * sola**: que el token dure una hora no puede convertirse en un error que el
 * usuario vea.
 */
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const base = inject(API_BASE_URL);
  const session = inject(SessionService);

  // Los assets propios —traducciones e iconos— no llevan credenciales.
  if (!req.url.startsWith(base)) return next(req);

  const withBearer = (request: HttpRequest<unknown>, token: string | null) =>
    next(token ? request.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : request);

  // El camino de sesión se autentica con la cookie, no con el bearer, y
  // reintentarlo tras un 401 sería un bucle.
  if (req.url.startsWith(`${base}/auth/web/`)) return next(req);

  return withBearer(req, session.accessToken()).pipe(
    catchError((error: unknown) => {
      if (!(error instanceof HttpErrorResponse) || error.status !== 401) {
        return throwError(() => error);
      }
      return session.refresh().pipe(switchMap((token) => withBearer(req, token)));
    }),
  );
};
