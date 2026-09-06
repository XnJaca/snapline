import { ProjectStatus } from './entities/project.entity';
import { PROJECT_TRANSITIONS } from './project-status';

/**
 * El mapeo de `docs/domain/proyecto.md`: los siete estados internos se agrupan
 * en cuatro etapas para el cliente final.
 *
 * El getter vive en la entity, así que se prueba sobre una instancia mínima en
 * vez de importar la constante, que no se exporta.
 */
import { Project } from './entities/project.entity';

const etapaDe = (status: ProjectStatus) => Object.assign(new Project(), { status }).clientStage;

describe('la etapa que ve el cliente', () => {
  it('agrupa los tres estados tempranos en Inicio', () => {
    for (const estado of ['LEAD', 'ESTIMATED', 'SCHEDULED'] as const) {
      expect(etapaDe(estado)).toBe('INICIO');
    }
  });

  it('la pausa se ve igual que el trabajo en curso', () => {
    // A propósito: el cliente no tiene por qué enterarse de que la obra estuvo
    // pausada tres días.
    expect(etapaDe('IN_PROGRESS')).toBe('EN_PROCESO');
    expect(etapaDe('ON_HOLD')).toBe('EN_PROCESO');
  });

  it('cancelada no se ve como terminada', () => {
    // **El bug que este test cierra.** El mapeo mandaba CANCELLED a FINALIZADO,
    // así que al cliente cuya obra se canceló el portal le decía que estaba
    // terminada. Los dos son estados finales, pero no significan lo mismo.
    expect(etapaDe('COMPLETED')).toBe('FINALIZADO');
    expect(etapaDe('CANCELLED')).toBe('CANCELADO');
    expect(etapaDe('CANCELLED')).not.toBe(etapaDe('COMPLETED'));
  });

  it('los siete estados tienen etapa, y ninguna es indefinida', () => {
    // Un estado nuevo sin fila en el mapeo llegaría al portal como `undefined`.
    for (const estado of Object.keys(PROJECT_TRANSITIONS) as ProjectStatus[]) {
      expect(['INICIO', 'EN_PROCESO', 'FINALIZADO', 'CANCELADO']).toContain(etapaDe(estado));
    }
  });
});
