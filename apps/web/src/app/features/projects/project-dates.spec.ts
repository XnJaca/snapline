import { projectDates } from './project-dates';

const fmt = (iso: string) => iso.slice(0, 10);

describe('las fechas de la tarjeta', () => {
  it('con las dos, un rango', () => {
    expect(projectDates({ startDate: '2026-08-12', targetEndDate: '2026-08-30' }, fmt))
      .toEqual({ key: 'projects.dateRange', params: { from: '2026-08-12', to: '2026-08-30' } });
  });

  it('con solo inicio, desde cuándo', () => {
    expect(projectDates({ startDate: '2026-09-10', targetEndDate: null }, fmt))
      .toEqual({ key: 'projects.dateFrom', params: { from: '2026-09-10' } });
  });

  it('con solo entrega, para cuándo', () => {
    expect(projectDates({ startDate: null, targetEndDate: '2026-07-02' }, fmt))
      .toEqual({ key: 'projects.dateUntil', params: { to: '2026-07-02' } });
  });

  it('sin fechas no dice nada, en vez de dibujar una línea vacía', () => {
    expect(projectDates({ startDate: null, targetEndDate: null }, fmt)).toBeNull();
  });

  /**
   * Devuelve clave y parámetros, nunca texto armado: el separador y el orden son
   * parte de lo que se traduce (regla 24).
   */
  it('nunca concatena el texto a mano', () => {
    const r = projectDates({ startDate: '2026-08-12', targetEndDate: '2026-08-30' }, fmt);
    expect(r?.key).toMatch(/^projects\./);
    expect(JSON.stringify(r)).not.toContain('–');
  });
});
