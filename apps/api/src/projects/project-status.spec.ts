import { ProjectStatus } from './entities/project.entity';
import { PROJECT_TRANSITIONS, canTransition, shouldDiscardStatus } from './project-status';

/**
 * La escalera de `docs/domain/proyecto.md`.
 *
 * El servidor es el que la valida: el móvil ofrece solo las válidas en su
 * selector, pero un dispositivo con una versión vieja de la app puede mandar
 * cualquier cosa por la bandeja.
 */
describe('escalera de estados del proyecto', () => {
  it('el camino normal está permitido de punta a punta', () => {
    expect(canTransition('LEAD', 'ESTIMATED')).toBe(true);
    expect(canTransition('ESTIMATED', 'SCHEDULED')).toBe(true);
    expect(canTransition('SCHEDULED', 'IN_PROGRESS')).toBe(true);
    expect(canTransition('IN_PROGRESS', 'COMPLETED')).toBe(true);
  });

  it('no se puede saltar etapas', () => {
    // El criterio del spec: desde LEAD no se llega a COMPLETED.
    expect(canTransition('LEAD', 'COMPLETED')).toBe(false);
    expect(canTransition('LEAD', 'IN_PROGRESS')).toBe(false);
    expect(canTransition('ESTIMATED', 'COMPLETED')).toBe(false);
  });

  it('de la pausa se vuelve', () => {
    // Sin esto una obra en pausa quedaba trabada para siempre.
    expect(canTransition('IN_PROGRESS', 'ON_HOLD')).toBe(true);
    expect(canTransition('ON_HOLD', 'IN_PROGRESS')).toBe(true);
  });

  it('se cancela desde cualquier estado vivo', () => {
    // El caso más común es el más temprano: no aceptaron el estimado.
    for (const desde of ['LEAD', 'ESTIMATED', 'SCHEDULED', 'IN_PROGRESS', 'ON_HOLD'] as const) {
      expect(canTransition(desde, 'CANCELLED')).toBe(true);
    }
  });

  it('terminada y cancelada son finales', () => {
    expect(PROJECT_TRANSITIONS.COMPLETED).toHaveLength(0);
    expect(PROJECT_TRANSITIONS.CANCELLED).toHaveLength(0);
    // Reabrir dejaría "terminada" sin significado para el reporte y para publicar.
    expect(canTransition('COMPLETED', 'IN_PROGRESS')).toBe(false);
    expect(canTransition('CANCELLED', 'LEAD')).toBe(false);
  });

  it('quedarse en el mismo estado no es una transición', () => {
    // Un `update` que manda el mismo estado con otros campos no debe fallar.
    for (const estado of Object.keys(PROJECT_TRANSITIONS) as ProjectStatus[]) {
      expect(canTransition(estado, estado)).toBe(true);
    }
  });

  it('ninguna transición declarada apunta a un estado inexistente', () => {
    const conocidos = Object.keys(PROJECT_TRANSITIONS);
    for (const destinos of Object.values(PROJECT_TRANSITIONS)) {
      for (const destino of destinos) expect(conocidos).toContain(destino);
    }
  });
});

describe('el cambio de estado que llega tarde', () => {
  // **El test que faltaba.** `isBackwards` clasificaba `ON_HOLD → IN_PROGRESS`
  // como retroceso, porque comparaba índices de un orden lineal donde `ON_HOLD`
  // va después de `IN_PROGRESS`. Reanudar una obra pausada —la transición más
  // común del dominio— se descartaba en silencio. Recorrer todos los pares lo
  // habría cazado antes de que llegara a una revisión.
  it('ninguna transición válida se descarta', () => {
    const descartadas: string[] = [];
    for (const [from, destinos] of Object.entries(PROJECT_TRANSITIONS)) {
      for (const to of destinos as readonly ProjectStatus[]) {
        if (shouldDiscardStatus(from as ProjectStatus, to)) {
          descartadas.push(`${from} -> ${to}`);
        }
      }
    }
    expect(descartadas).toEqual([]);
  });

  it('reanudar una obra pausada no se descarta', () => {
    // El caso concreto que se perdía. Explícito además del barrido de arriba,
    // para que se lea en el nombre del test.
    expect(shouldDiscardStatus('ON_HOLD', 'IN_PROGRESS')).toBe(false);
    expect(canTransition('ON_HOLD', 'IN_PROGRESS')).toBe(true);
  });

  it('lo que ya no es válido se descarta en vez de fallar', () => {
    // La obra avanzó mientras el teléfono no tenía señal.
    expect(shouldDiscardStatus('COMPLETED', 'IN_PROGRESS')).toBe(true);
    expect(shouldDiscardStatus('COMPLETED', 'ON_HOLD')).toBe(true);
    expect(shouldDiscardStatus('IN_PROGRESS', 'SCHEDULED')).toBe(true);
    // Y también lo que dejó de ser válido sin ser retroceso: el teléfono creía la
    // obra en `IN_PROGRESS`, donde `COMPLETED` sí era válido. Con un error se
    // quedaría en su bandeja reintentándose para siempre.
    expect(shouldDiscardStatus('ON_HOLD', 'COMPLETED')).toBe(true);
  });

  it('quedarse en el mismo estado no se descarta', () => {
    for (const estado of Object.keys(PROJECT_TRANSITIONS) as ProjectStatus[]) {
      expect(shouldDiscardStatus(estado, estado)).toBe(false);
    }
  });
});
