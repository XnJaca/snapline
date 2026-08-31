import { TimeEntriesService } from './time-entries.service';
import { TenantContext } from '../tenant/tenant-context';
import { TimeEntry } from './entities/time-entry.entity';
import { ApproveDto } from './dto/time-entry.dto';
import { ApiError } from '../common/errors/api-error';

/**
 * Aprobar y rechazar una jornada (SPEC-0011).
 *
 * Lo que se fija acá es lo que la regla 12 no deja improvisar: cuándo una
 * decisión que llega tarde se aplica, cuándo es benigna y cuándo es divergencia
 * que tiene que mirar una persona.
 */
const service = new TimeEntriesService({} as never, {} as never, {} as never, {} as never);

const tenant = (membershipId = 'jefe'): TenantContext =>
  ({ companyId: 'c1', membershipId, role: 'OWNER' }) as TenantContext;

const entry = (status: TimeEntry['status'], membershipId = 'maria'): TimeEntry =>
  ({ id: 't1', membershipId, status, clockOutAt: new Date() }) as TimeEntry;

const decidible = (e: TimeEntry, destino: TimeEntry['status'], dto: ApproveDto = {}) =>
  (service as never as {
    assertDecidable(e: TimeEntry, d: TimeEntry['status'], dto: ApproveDto, t: TenantContext): void;
  }).assertDecidable(e, destino, dto, tenant());

const codigo = (fn: () => void): string => {
  try {
    fn();
  } catch (e) {
    return e instanceof ApiError ? e.code : 'SIN_CODIGO';
  }
  return 'NO_LANZO';
};

describe('nadie decide sobre sus propias horas', () => {
  it('ni siquiera un OWNER', () => {
    expect(codigo(() => decidible(entry('PENDING', 'jefe'), 'APPROVED')))
      .toBe('CANNOT_APPROVE_OWN_HOURS');
  });
});

describe('una decisión que ya está tomada', () => {
  it('aprobar algo ya aprobado es benigno: alguien decidió lo mismo', () => {
    expect(codigo(() => decidible(entry('APPROVED'), 'APPROVED')))
      .toBe('TIME_ENTRY_DECISION_MATCHES');
  });

  it('rechazar algo ya rechazado también, y por eso el código no dice APPROVED', () => {
    // Dos ADMIN rechazando lo mismo sin señal es igual de "ya decidido" que dos
    // aprobándolo. Un código llamado ALREADY_APPROVED mentiría acá.
    expect(codigo(() => decidible(entry('REJECTED'), 'REJECTED')))
      .toBe('TIME_ENTRY_DECISION_MATCHES');
  });
});

describe('expectedStatus separa la corrección deliberada del choque real', () => {
  it('aprobar una rechazada, viéndola rechazada, es corregir y se aplica', () => {
    expect(codigo(() => decidible(entry('REJECTED'), 'APPROVED', { expectedStatus: 'REJECTED' })))
      .toBe('NO_LANZO');
  });

  it('aprobar creyéndola pendiente, cuando otro ya la rechazó, es conflicto', () => {
    expect(codigo(() => decidible(entry('REJECTED'), 'APPROVED', { expectedStatus: 'PENDING' })))
      .toBe('TIME_ENTRY_DECISION_CONFLICTS');
  });

  it('y al revés: rechazar creyéndola pendiente cuando otro la aprobó', () => {
    // La dirección que el código no cubría: approve() solo miraba APPROVED, así
    // que un approve encolado sobre algo rechazado se aplicaba en silencio.
    expect(codigo(() => decidible(entry('APPROVED'), 'REJECTED', { expectedStatus: 'PENDING' })))
      .toBe('TIME_ENTRY_DECISION_CONFLICTS');
  });

  it('sin expectedStatus —la web, que es online— se aplica como antes', () => {
    expect(codigo(() => decidible(entry('PENDING'), 'APPROVED'))).toBe('NO_LANZO');
  });
});
