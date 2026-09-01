import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { SessionService } from './session.service';

/**
 * `offline` deja pasar a propósito: la app muestra el aviso de conexión sobre la
 * ruta y conserva la URL, en vez de mandar a login como si la sesión hubiera
 * vencido.
 */
export const sessionGuard: CanActivateFn = async () => {
  const session = inject(SessionService);
  const router = inject(Router);

  if (session.status() === 'unknown') await session.restore();
  return session.status() === 'anonymous' ? router.createUrlTree(['/login']) : true;
};

/** Quien ya está adentro no vuelve al formulario de entrada. */
export const anonymousGuard: CanActivateFn = async () => {
  const session = inject(SessionService);
  const router = inject(Router);

  if (session.status() === 'unknown') await session.restore();
  return session.status() === 'authenticated' ? router.createUrlTree(['/']) : true;
};
