import { TimeEntriesService } from './time-entries.service';
import { TenantContext } from '../tenant/tenant-context';

/**
 * Quién marcó y qué alcance de lectura tiene cada rol. La parte con base de
 * datos —la bandera de asignación, el recorte real de la lista— se verifica en
 * los edge-cases de Bruno contra el API vivo.
 */
const service = new TimeEntriesService({} as never, {} as never, {} as never, {} as never);

const tenant = (role: TenantContext['role']): TenantContext =>
  ({ companyId: 'c1', membershipId: 'yo', role }) as TenantContext;

// método privado a propósito: el contrato es clockIn, esto fija su regla
const methodFor = (t: TenantContext, target: string) =>
  (service as never as { methodFor(t: TenantContext, m: string): string }).methodFor(t, target);

const soloLoPropio = (t: TenantContext) =>
  (service as never as { soloLoPropio(t: TenantContext): boolean }).soloLoPropio(t);

describe('method sale del rol de quien marca', () => {
  it('marcarse a uno mismo es SELF, con cualquier rol', () => {
    expect(methodFor(tenant('WORKER'), 'yo')).toBe('SELF');
    expect(methodFor(tenant('OWNER'), 'yo')).toBe('SELF');
  });

  it('un foreman que marca por otro queda como FOREMAN', () => {
    expect(methodFor(tenant('FOREMAN'), 'otra-persona')).toBe('FOREMAN');
  });

  it('el dueño que marca por otro queda como ADMIN, no FOREMAN', () => {
    // "Lo marcó un foreman" cuando lo marcó el dueño es un dato falso en el
    // rastro que la regla 12 protege.
    expect(methodFor(tenant('OWNER'), 'otra-persona')).toBe('ADMIN');
    expect(methodFor(tenant('ADMIN'), 'otra-persona')).toBe('ADMIN');
  });
});

describe('el alcance de lectura por rol', () => {
  it('un WORKER lee solo lo propio', () => {
    expect(soloLoPropio(tenant('WORKER'))).toBe(true);
  });

  it('los demás roles con time.read leen el alcance completo', () => {
    expect(soloLoPropio(tenant('OWNER'))).toBe(false);
    expect(soloLoPropio(tenant('ADMIN'))).toBe(false);
    expect(soloLoPropio(tenant('FOREMAN'))).toBe(false);
    expect(soloLoPropio(tenant('ACCOUNTANT'))).toBe(false);
  });
});
