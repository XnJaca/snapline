import { ThrottlerModuleOptions } from '@nestjs/throttler';

/**
 * Tres perfiles. El que importa es `strict`: se aplica a lo que se puede atacar
 * sin credenciales — login y el token del portal del cliente.
 */
export const throttleConfig: ThrottlerModuleOptions = {
  throttlers: [
    { name: 'default', ttl: 60_000, limit: 120 },
    { name: 'strict', ttl: 60_000, limit: 8 },
  ],
};
