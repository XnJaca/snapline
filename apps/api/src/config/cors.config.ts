import { Logger } from '@nestjs/common';
import { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

/**
 * Orígenes explícitos, **nunca `*`**: con `credentials: true` el navegador
 * rechaza el comodín, y en producción sería un agujero (ADR-0014 §4).
 *
 * Sin la variable no se habilita ninguno. Un panel que no carga se nota; un
 * origen abierto por default, no.
 */
export function corsOptions(env: NodeJS.ProcessEnv = process.env): CorsOptions {
  const origin = (env.WEB_ORIGIN ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  if (!origin.length) {
    Logger.warn('WEB_ORIGIN sin configurar: el panel no va a poder llamar al API', 'Cors');
  }

  return { origin, credentials: true, methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'] };
}
