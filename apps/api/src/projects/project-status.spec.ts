import { ProjectStatus } from './entities/project.entity';
import { PROJECT_TRANSITIONS, canTransition, isBackwards } from './project-status';

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
      expect(isBackwards(estado, estado)).toBe(false);
    }
  });

  it('ninguna transición declarada apunta a un estado inexistente', () => {
    const conocidos = Object.keys(PROJECT_TRANSITIONS);
    for (const destinos of Object.values(PROJECT_TRANSITIONS)) {
      for (const destino of destinos) expect(conocidos).toContain(destino);
    }
  });
});

describe('la transición que llega tarde', () => {
  it('retroceder en el ciclo es hacia atrás', () => {
    expect(isBackwards('COMPLETED', 'IN_PROGRESS')).toBe(true);
    expect(isBackwards('IN_PROGRESS', 'SCHEDULED')).toBe(true);
    expect(isBackwards('SCHEDULED', 'LEAD')).toBe(true);
  });

  it('avanzar no lo es', () => {
    expect(isBackwards('LEAD', 'ESTIMATED')).toBe(false);
    expect(isBackwards('IN_PROGRESS', 'COMPLETED')).toBe(false);
  });

  it('cancelar nunca es retroceder', () => {
    // Es una decisión que se toma en cualquier punto, no una orden vieja.
    expect(isBackwards('COMPLETED', 'CANCELLED')).toBe(false);
    expect(isBackwards('LEAD', 'CANCELLED')).toBe(false);
  });

  it('pausar una obra entregada es una orden vieja; pausar una en marcha no', () => {
    expect(isBackwards('COMPLETED', 'ON_HOLD')).toBe(true);
    expect(isBackwards('IN_PROGRESS', 'ON_HOLD')).toBe(false);
  });
});
