/**
 * El panel llama al API por su origen, no por un proxy: la cookie de sesión y el
 * preflight tienen que comportarse igual en desarrollo que en producción
 * (ADR-0014 §4). El origen que se acepta lo declara el API en `WEB_ORIGIN`.
 *
 * El despliegue reemplaza este archivo cuando exista un dominio.
 */
export const environment = {
  apiBaseUrl: 'http://localhost:3000/api',
};
