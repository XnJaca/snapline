import type { ChipTone } from '../../shared/chip/chip';

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

/**
 * Las obras a las que todavía tiene sentido mandar una cuadrilla. Una terminada
 * o cancelada no recibe gente nueva, y una en pausa tampoco.
 *
 * Los nombres salen del enum del API (`project_status`): escribirlos a mano en
 * cada pantalla ya se pagó una vez —`ESTIMATING` no existe, y una obra estimada
 * nunca aparecía en el selector de asignar, sin ningún error a la vista—.
 */
export const OPEN_PROJECT_STATUSES = [
  'LEAD',
  'ESTIMATED',
  'SCHEDULED',
  'IN_PROGRESS',
] as const;

export function isOpenProject(status: string): boolean {
  return (OPEN_PROJECT_STATUSES as readonly string[]).includes(status);
}
