import type { Project, ProjectStatus } from './projects.api';

/** El filtro de estado sin filtrar. No es un estado del dominio: es "no filtrar". */
export const ALL_STATUSES = 'ALL' as const;
export type StatusFilter = ProjectStatus | typeof ALL_STATUSES;

/**
 * Busca por lo que alguien tiene a mano cuando busca una obra: cómo se llama, o
 * de quién es — y nada más, que es lo que pide el spec. El cliente viaja embebido
 * en cada proyecto, así que no hace falta resolverlo aparte.
 *
 * Función aparte y no un método del componente para poder probarla sin montar
 * media aplicación, igual que `filterCustomers`.
 */
export function filterProjects(
  projects: readonly Project[],
  query: string,
  status: StatusFilter,
): Project[] {
  const q = query.trim().toLowerCase();

  return projects.filter((p) => {
    if (status !== ALL_STATUSES && p.status !== status) return false;
    if (!q) return true;
    return [p.name, p.customer?.displayName].some((campo) => campo?.toLowerCase().includes(q));
  });
}
