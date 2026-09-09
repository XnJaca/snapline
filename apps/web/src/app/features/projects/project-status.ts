import type { ChipTone } from '../../shared/chip/chip';
import type { ProjectStatus } from './projects.api';

/**
 * Los siete del dominio, en el orden del ciclo de vida. El filtro de la lista y
 * el selector del alta los recorren; ninguno de los dos escribe su propia lista.
 */
export const PROJECT_STATUSES: readonly ProjectStatus[] = [
  'LEAD', 'ESTIMATED', 'SCHEDULED', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED',
];

/**
 * Una obra no nace cancelada: cancelar es abandonar un trabajo que se había
 * tomado, y eso supone que antes existió. `COMPLETED` sí se ofrece, porque
 * cargar una obra vieja ya terminada es cómo entra el portafolio de los años
 * anteriores. Ver la ficha `proyecto`.
 */
export const NEW_PROJECT_STATUSES: readonly ProjectStatus[] =
  PROJECT_STATUSES.filter((s) => s !== 'CANCELLED');

const TONE: Record<string, ChipTone> = {
  LEAD: 'neutral',
  ESTIMATED: 'neutral',
  SCHEDULED: 'info',
  IN_PROGRESS: 'info',
  COMPLETED: 'success',
  ON_HOLD: 'warning',
  CANCELLED: 'danger',
};

export function projectStatusTone(status: string): ChipTone {
  return TONE[status] ?? 'neutral';
}

/** Una obra cerrada, en pausa o abandonada no recibe gente nueva. */
const CLOSED_PROJECT_STATUSES: readonly ProjectStatus[] =
  ['ON_HOLD', 'COMPLETED', 'CANCELLED'];

/**
 * Las obras a las que todavía tiene sentido asignar una cuadrilla. **Se deriva
 * de `PROJECT_STATUSES`**, no se escribe aparte: la lista suelta ya se pagó una
 * vez —decía `ESTIMATING`, que no existe en el enum, y una obra estimada nunca
 * aparecía en el selector de asignar sin ningún error a la vista—.
 */
export const OPEN_PROJECT_STATUSES: readonly ProjectStatus[] =
  PROJECT_STATUSES.filter((s) => !CLOSED_PROJECT_STATUSES.includes(s));

export function isOpenProject(status: string): boolean {
  return (OPEN_PROJECT_STATUSES as readonly string[]).includes(status);
}
