import { ThrottlerModuleOptions } from '@nestjs/throttler';

/**
 * **Un solo perfil global.** Con más de uno declarado, `@nestjs/throttler` los
 * evalúa todos en cada request — el límite estricto pensado para login terminaba
 * cortando la app entera a 8 llamadas por minuto.
 *
 * Lo estricto se aplica por endpoint con `@StrictThrottle()`, que sobrescribe
 * este mismo perfil donde hace falta.
 *
 * En test el límite sube: una suite e2e hace cientos de requests en segundos y
 * empezaría a fallar por `429` en vez de por lo que prueba.
 */
const enTest = process.env.NODE_ENV === 'test';

export const throttleConfig: ThrottlerModuleOptions = {
  throttlers: [{ name: 'default', ttl: 60_000, limit: enTest ? 10_000 : 120 }],
};

/** Lo que se puede atacar sin credenciales: login y el token del portal. */
export const STRICT_LIMIT = { ttl: 60_000, limit: 8 };
