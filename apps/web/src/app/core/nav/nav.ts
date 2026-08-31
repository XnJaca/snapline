import { IconName } from '../icons/icons';

export interface NavAxis {
  readonly path: string;
  readonly permission: string;
  readonly icon: IconName;
  readonly label: string;
}

/**
 * Cada eje cuelga de un permiso que el API ya calcula y manda en el login. La
 * tabla de roles no se replica acá: un permiso nuevo llega solo, y el guard del
 * API sigue siendo quien autoriza.
 */
export const NAV: readonly NavAxis[] = [
  { path: 'projects', permission: 'projects.read', icon: 'projects', label: 'nav.projects' },
  { path: 'customers', permission: 'customers.read', icon: 'customers', label: 'nav.customers' },
  { path: 'crews', permission: 'crews.read', icon: 'crews', label: 'nav.crews' },
  { path: 'hours', permission: 'time.read', icon: 'hours', label: 'nav.hours' },
  { path: 'catalog', permission: 'catalog.read', icon: 'catalog', label: 'nav.catalog' },
  { path: 'billing', permission: 'billing.read', icon: 'billing', label: 'nav.billing' },
  { path: 'reports', permission: 'reports.read', icon: 'reports', label: 'nav.reports' },
  { path: 'publish', permission: 'projects.publish', icon: 'publish', label: 'nav.publish' },
];

export function visibleAxes(permissions: readonly string[]): NavAxis[] {
  return NAV.filter((axis) => permissions.includes(axis.permission));
}
