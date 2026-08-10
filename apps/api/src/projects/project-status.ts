import { ProjectStatus } from './entities/project.entity';

/**
 * Las transiciones válidas de `docs/domain/proyecto.md`.
 *
 * Vive acá y no en el servicio para que el móvil pueda ofrecer exactamente las
 * mismas en su selector: una tabla en cada lado divergiría, y la que se ve en la
 * pantalla dejaría de ser la que el servidor acepta.
 */
export const PROJECT_TRANSITIONS = {
  LEAD: ['ESTIMATED', 'CANCELLED'],
  ESTIMATED: ['SCHEDULED', 'CANCELLED'],
  SCHEDULED: ['IN_PROGRESS', 'ON_HOLD', 'CANCELLED'],
  IN_PROGRESS: ['COMPLETED', 'ON_HOLD', 'CANCELLED'],
  ON_HOLD: ['IN_PROGRESS', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
} as const satisfies Record<ProjectStatus, readonly ProjectStatus[]>;

/** El orden del ciclo de vida. Define qué es "hacia atrás". */
const ORDEN: readonly ProjectStatus[] = [
  'LEAD',
  'ESTIMATED',
  'SCHEDULED',
  'IN_PROGRESS',
  'ON_HOLD',
  'COMPLETED',
  'CANCELLED',
];

export function canTransition(from: ProjectStatus, to: ProjectStatus): boolean {
  // Quedarse donde está no es una transición: un `update` que manda el mismo
  // estado junto con otros campos no tiene por qué fallar.
  if (from === to) return true;
  return (PROJECT_TRANSITIONS[from] as readonly ProjectStatus[]).includes(to);
}

/**
 * Una transición que llega tarde desde un dispositivo con el estado viejo.
 *
 * **Es lo único de `project` que no es última escritura gana.** El móvil no puede
 * decidirlo: sincroniza cuando hay señal y no sabe si mientras tanto la obra
 * avanzó. Lo descarta el servidor, que es el único que ve los dos estados.
 *
 * `ON_HOLD` cuenta como retroceso frente a `COMPLETED` y no frente a
 * `IN_PROGRESS`: pausar una obra en marcha es una operación normal, pero pausar
 * una que ya se entregó es una orden vieja que llegó tarde.
 */
export function isBackwards(from: ProjectStatus, to: ProjectStatus): boolean {
  if (from === to) return false;
  // Cancelar nunca es retroceder: es una decisión que se toma en cualquier punto.
  if (to === 'CANCELLED') return false;
  return ORDEN.indexOf(to) < ORDEN.indexOf(from);
}
