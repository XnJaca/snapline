import { MigrationInterface, QueryRunner } from 'typeorm';

// El login es anterior al contexto de tenant: no puede setear app.company_id
// porque todavía no sabe la empresa. Esta función SECURITY DEFINER es el único
// camino que lee membership sin GUC, acotado a resolver la sesión.
export class AuthLookup1786168800004 implements MigrationInterface {
  name = 'AuthLookup1786168800004';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE FUNCTION auth_memberships_for_user(p_user_id uuid)
      RETURNS TABLE (id uuid, company_id uuid, role membership_role, pay_rate_cents bigint)
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      STABLE
      AS $fn$
        SELECT m.id, m.company_id, m.role, m.pay_rate_cents
        FROM membership m
        WHERE m.user_id = p_user_id
          AND m.status = 'ACTIVE'
          AND m.deleted_at IS NULL
        ORDER BY m.created_at ASC
      $fn$`);

    await q.query(`REVOKE EXECUTE ON FUNCTION auth_memberships_for_user(uuid) FROM PUBLIC`);
    await q.query(`GRANT EXECUTE ON FUNCTION auth_memberships_for_user(uuid) TO snapline_app`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP FUNCTION IF EXISTS auth_memberships_for_user(uuid)`);
  }
}
