import { applyDecorators } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { STRICT_LIMIT } from './throttle.config';

/**
 * Para endpoints que aceptan credenciales o tokens sin autenticación previa.
 * Sin esto, adivinar un token del portal es cuestión de tiempo de CPU.
 *
 * Sobrescribe el perfil `default` en vez de sumar uno nuevo: un throttler extra
 * declarado en la config se aplicaría a **todas** las rutas.
 */
export const StrictThrottle = () =>
  applyDecorators(Throttle({ default: STRICT_LIMIT }));
