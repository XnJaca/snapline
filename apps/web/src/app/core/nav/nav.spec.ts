import { NAV, visibleAxes } from './nav';

/**
 * La navegación se dibuja desde los permisos que el API manda en el login. Si
 * esto alguna vez ramifica por rol, la tabla quedó duplicada en dos lenguajes.
 */
describe('navegación del panel', () => {
  // Los mismos que devuelve permissionsForRole() en el API.
  const OWNER = ['customers.read', 'projects.read', 'projects.publish', 'crews.read',
    'time.read', 'catalog.read', 'billing.read', 'reports.read'];
  const WORKER = ['projects.read', 'time.clock', 'time.read', 'media.capture'];
  const ACCOUNTANT = ['customers.read', 'projects.read', 'time.read', 'catalog.read',
    'billing.read', 'reports.read'];

  it('el OWNER ve los ocho ejes', () => {
    expect(visibleAxes(OWNER)).toHaveLength(NAV.length);
  });

  it('un WORKER encuentra Proyectos y Horas, y nada más', () => {
    expect(visibleAxes(WORKER).map((axis) => axis.path)).toEqual(['projects', 'hours']);
  });

  it('sin billing.read no hay Facturación', () => {
    expect(visibleAxes(WORKER).some((axis) => axis.path === 'billing')).toBe(false);
    expect(visibleAxes(ACCOUNTANT).some((axis) => axis.path === 'billing')).toBe(true);
  });

  // El contador no toca fotos: publicar no puede aparecerle aunque lea todo lo demás.
  it('publicar cuelga de projects.publish, no de projects.read', () => {
    expect(visibleAxes(ACCOUNTANT).some((axis) => axis.path === 'publish')).toBe(false);
  });

  it('sin permisos no se dibuja ningún eje', () => {
    expect(visibleAxes([])).toEqual([]);
  });
});
