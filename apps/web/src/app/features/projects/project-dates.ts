import type { Project } from './projects.api';

/**
 * Qué decir de las fechas de una obra según cuáles tenga cargadas. Devuelve la
 * clave y sus parámetros, no un texto armado: el separador y el orden son parte
 * de lo que se traduce, y `"{inicio} – {fin}"` no se concatena a mano (regla 24).
 */
export function projectDates(
  project: Pick<Project, 'startDate' | 'targetEndDate'>,
  formato: (iso: string) => string,
): { key: string; params: Record<string, string> } | null {
  const { startDate: desde, targetEndDate: hasta } = project;

  if (desde && hasta) {
    return { key: 'projects.dateRange', params: { from: formato(desde), to: formato(hasta) } };
  }
  if (desde) return { key: 'projects.dateFrom', params: { from: formato(desde) } };
  if (hasta) return { key: 'projects.dateUntil', params: { to: formato(hasta) } };
  return null;
}
