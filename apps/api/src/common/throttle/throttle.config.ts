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

/**
 * Lo que se puede atacar sin credenciales: login, el canje del código y el token
 * del portal.
 *
 * Sube en test por la misma razón que el perfil general: una suite que recorre
 * el alta, el canje y el pull hace más de ocho llamadas de auth en segundos, y
 * el `429` haría fallar el test por el límite y no por lo que prueba. **El
 * número de producción no cambia**, que es el que importa.
 */
export const STRICT_LIMIT = { ttl: 60_000, limit: enTest ? 10_000 : 8 };
