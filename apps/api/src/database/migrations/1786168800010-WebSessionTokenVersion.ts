import { MigrationInterface, QueryRunner } from 'typeorm';

// Sin este contador, cerrar sesión no invalida nada: el refresh es un JWT
// autofirmado y vale 30 días. Ver ADR-0014 §3b.
export class WebSessionTokenVersion1786168800010 implements MigrationInterface {
  name = 'WebSessionTokenVersion1786168800010';

  public async up(q: QueryRunner): Promise<void> {
    // DEFAULT 0 deja en cero a las membresías que ya existen: un refresh emitido
    // antes del deploy compara 0 contra 0 y sigue sirviendo.
    await q.query(`ALTER TABLE membership ADD COLUMN token_version integer NOT NULL DEFAULT 0`);

    // La función es el único camino sancionado para leer membership sin contexto
    // de tenant, y refresh() necesita el contador justo ahí. CREATE OR REPLACE no
    // sirve: cambia el tipo de retorno, y Postgres lo rechaza.
    await q.query(`DROP FUNCTION IF EXISTS auth_memberships_for_user(uuid)`);
    await q.query(`
      CREATE FUNCTION auth_memberships_for_user(p_user_id uuid)
      RETURNS TABLE (id uuid, company_id uuid, role membership_role, pay_rate_cents bigint, token_version integer)
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      STABLE
      AS $fn$
        SELECT m.id, m.company_id, m.role, m.pay_rate_cents, m.token_version
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
    await q.query(`ALTER TABLE membership DROP COLUMN token_version`);
  }
}
