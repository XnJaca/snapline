import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Registro de operaciones de sync ya aplicadas.
 *
 * Antes, "ya aplicado" se decidía preguntando si existía una fila con ese id.
 * Eso funciona para las altas —el id lo genera el dispositivo— pero se rompe con
 * las correcciones: en un `update` el recurso siempre existe, así que el primer
 * intento habría vuelto `duplicate` sin aplicar nada nunca.
 *
 * La clave es el `client_id` que manda el dispositivo, por empresa. Reintentar
 * con la misma clave devuelve `duplicate`, que es lo que la regla 19 pide.
 */
export class SyncOperationLog1786168800007 implements MigrationInterface {
  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE sync_operation (
        id uuid PRIMARY KEY,
        company_id uuid NOT NULL REFERENCES company(id),
        client_id uuid NOT NULL,
        type text NOT NULL,
        target_id uuid NOT NULL,
        resource_id uuid,
        applied_at timestamptz NOT NULL DEFAULT now()
      )`);

    // La idempotencia es por empresa: dos dispositivos de tenants distintos
    // podrían generar el mismo UUID sin que uno pise al otro.
    await q.query(`
      CREATE UNIQUE INDEX sync_operation_client_id_unique
      ON sync_operation (company_id, client_id)`);

    await q.query(`ALTER TABLE sync_operation ENABLE ROW LEVEL SECURITY`);
    await q.query(`ALTER TABLE sync_operation FORCE ROW LEVEL SECURITY`);
    await q.query(`
      CREATE POLICY sync_operation_tenant_isolation ON sync_operation
      USING (company_id = app_current_company())
      WITH CHECK (company_id = app_current_company())`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE IF EXISTS sync_operation`);
  }
}
