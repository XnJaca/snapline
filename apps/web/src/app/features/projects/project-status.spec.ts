import { NEW_PROJECT_STATUSES, PROJECT_STATUSES, projectStatusTone } from './project-status';

describe('estados de la obra en el panel', () => {
  it('el filtro ofrece los siete del dominio', () => {
    expect(PROJECT_STATUSES).toHaveLength(7);
  });

  /**
   * El criterio del spec: una obra no nace cancelada. `COMPLETED` sí se ofrece,
   * porque cargar una obra vieja ya terminada es cómo entra el portafolio.
   */
  it('el alta ofrece seis: sin CANCELLED, con COMPLETED', () => {
    expect(NEW_PROJECT_STATUSES).toHaveLength(6);
    expect(NEW_PROJECT_STATUSES).not.toContain('CANCELLED');
    expect(NEW_PROJECT_STATUSES).toContain('COMPLETED');
  });

  it('cada estado tiene tono, y cancelado no se ve igual que terminado', () => {
    for (const estado of PROJECT_STATUSES) {
      expect(projectStatusTone(estado)).toBeTruthy();
    }
    expect(projectStatusTone('CANCELLED')).not.toBe(projectStatusTone('COMPLETED'));
  });
});
