import { OPERATION_PERMISSION, SYNC_OPERATIONS } from './dto/sync.dto';
import { roleHasPermission } from '../auth/permissions';

/**
 * El permiso que exige cada operación del lote.
 *
 * El endpoint entero entra con `time.clock` —el mínimo para que un trabajador
 * empuje su marcaje— así que esta tabla es lo único que separa a un `WORKER` de
 * hacer por la cola lo que la puerta REST le niega (regla 7).
 */
describe('toda operación declara su permiso', () => {
  it('ninguna queda sin declarar', () => {
    for (const op of SYNC_OPERATIONS) {
      expect(OPERATION_PERMISSION[op]).toBeDefined();
    }
  });
});

describe('decidir sobre horas no es marcarlas', () => {
  it('aprobar y rechazar piden `time.approve`, no `time.clock`', () => {
    expect(OPERATION_PERMISSION['timeEntry.approve']).toBe('time.approve');
    expect(OPERATION_PERMISSION['timeEntry.reject']).toBe('time.approve');
  });

  it('un WORKER puede marcar por la cola pero no aprobarse las horas', () => {
    expect(roleHasPermission('WORKER', OPERATION_PERMISSION['timeEntry.clockIn'])).toBe(true);
    expect(roleHasPermission('WORKER', OPERATION_PERMISSION['timeEntry.approve'])).toBe(false);
    expect(roleHasPermission('WORKER', OPERATION_PERMISSION['timeEntry.reject'])).toBe(false);
  });

  it('un FOREMAN tampoco: aprobar sigue siendo de la oficina', () => {
    expect(roleHasPermission('FOREMAN', OPERATION_PERMISSION['timeEntry.approve'])).toBe(false);
  });

  it('OWNER y ADMIN sí', () => {
    expect(roleHasPermission('OWNER', OPERATION_PERMISSION['timeEntry.approve'])).toBe(true);
    expect(roleHasPermission('ADMIN', OPERATION_PERMISSION['timeEntry.reject'])).toBe(true);
  });
});
