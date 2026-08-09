import { MigrationInterface, QueryRunner } from 'typeorm';

// El portal del cliente es anónimo: el token identifica la empresa, así que no
// puede setear app.company_id antes de resolverlo. Tercera y última función
// SECURITY DEFINER del sistema, acotada a canjear un token vigente.
export class ClientAccessLookup1786168800006 implements MigrationInterface {
  name = 'ClientAccessLookup1786168800006';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE FUNCTION client_access_by_token(p_token_hash text)
      RETURNS TABLE (id uuid, company_id uuid, customer_id uuid, project_id uuid)
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      STABLE
      AS $fn$
        SELECT a.id, a.company_id, a.customer_id, a.project_id
        FROM client_access a
        WHERE a.token_hash = p_token_hash
          AND a.revoked_at IS NULL
          AND a.expires_at > now()
        LIMIT 1
      $fn$`);

    await q.query(`REVOKE EXECUTE ON FUNCTION client_access_by_token(text) FROM PUBLIC`);
    await q.query(`GRANT EXECUTE ON FUNCTION client_access_by_token(text) TO snapline_app`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP FUNCTION IF EXISTS client_access_by_token(text)`);
  }
}
