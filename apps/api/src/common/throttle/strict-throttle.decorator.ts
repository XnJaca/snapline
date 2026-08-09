import { applyDecorators } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

/**
 * Para endpoints que aceptan credenciales o tokens sin autenticación previa.
 * Sin esto, adivinar un token del portal es cuestión de tiempo de CPU.
 */
export const StrictThrottle = () =>
  applyDecorators(Throttle({ strict: { ttl: 60_000, limit: 8 } }));
