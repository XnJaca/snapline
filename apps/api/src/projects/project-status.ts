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

export function canTransition(from: ProjectStatus, to: ProjectStatus): boolean {
  // Quedarse donde está no es una transición: un `update` que manda el mismo
  // estado junto con otros campos no tiene por qué fallar.
  if (from === to) return true;
  return (PROJECT_TRANSITIONS[from] as readonly ProjectStatus[]).includes(to);
}

/**
 * Si un cambio de estado que llegó por la bandeja hay que **ignorar** en vez de
 * rechazar.
 *
 * Es lo único de `project` que no es última escritura gana. El dispositivo pudo
 * pasar días sin señal: manda la transición que era válida **desde el estado que
 * él conocía**, y para cuando llega la obra ya avanzó. No puede saberlo, así que
 * lo resuelve el servidor, que es el único que ve los dos estados.
 *
 * **Se ignora cualquier transición que no sea válida ahora, no solo la
 * retrocedente.** Un teléfono que creía la obra en `IN_PROGRESS` y manda
 * `COMPLETED` cuando ya está en `ON_HOLD` mandó algo legítimo que dejó de serlo:
 * si respondiéramos error se quedaría en su bandeja reintentándose para siempre.
 *
 * No existe una función aparte que decida "esto es hacia atrás". La hubo, y
 * clasificaba `ON_HOLD → IN_PROGRESS` como retroceso porque comparaba índices de
 * un orden lineal donde `ON_HOLD` va después de `IN_PROGRESS` — y esa es la
 * transición más común del dominio, reanudar una obra pausada. Se perdía en
 * silencio. La escalera es una rama, no una fila: `canTransition` es la única
 * fuente.
 */
export function shouldDiscardStatus(
  from: ProjectStatus,
  to: ProjectStatus,
): boolean {
  return !canTransition(from, to);
}
