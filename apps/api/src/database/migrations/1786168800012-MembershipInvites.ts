import { MigrationInterface, QueryRunner } from 'typeorm';

// El código de invitación es lo que le faltaba al estado INVITED para ser
// alcanzable: la columna existe desde InitialSchema y hasta hoy nadie la escribe.
// La cuarta función SECURITY DEFINER del sistema, discutida en SPEC-0011: canjear
// un código es anterior a saber la empresa, igual que el login.
export class MembershipInvites1786168800012 implements MigrationInterface {
  name = 'MembershipInvites1786168800012';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      ALTER TABLE membership
        ADD COLUMN invite_code_hash  text,
        ADD COLUMN invite_expires_at timestamptz,
        ADD COLUMN invite_attempts   integer NOT NULL DEFAULT 0`);

    // Quien fue invitado y todavía no canjeó no tiene contraseña. El centinela
    // —hashear un secreto que se descarta— deja en la base un valor que parece
    // una contraseña y no lo es, y nada distingue a quien nunca entró.
    await q.query(`ALTER TABLE app_user ALTER COLUMN password_hash DROP NOT NULL`);

    // Devuelve también las vencidas: el servicio necesita distinguir un código
    // vencido de uno inventado, y esa diferencia no se puede hacer si la consulta
    // ya las filtró. El company_id no lo usa el canje para resolver la sesión, lo
    // usa para poder escribir después: el contador de intentos y la activación
    // atraviesan RLS con runAs(), como hace logout().
    await q.query(`
      CREATE FUNCTION auth_invites_for_user(p_user_id uuid)
      RETURNS TABLE (
        id uuid, company_id uuid, role membership_role,
        invite_code_hash text, invite_expires_at timestamptz, invite_attempts integer
      )
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      STABLE
      AS $fn$
        SELECT m.id, m.company_id, m.role,
               m.invite_code_hash, m.invite_expires_at, m.invite_attempts
        FROM membership m
        WHERE m.user_id = p_user_id
          AND m.status = 'INVITED'
          AND m.invite_code_hash IS NOT NULL
          AND m.deleted_at IS NULL
        ORDER BY m.created_at ASC
      $fn$`);

    await q.query(`REVOKE EXECUTE ON FUNCTION auth_invites_for_user(uuid) FROM PUBLIC`);
    await q.query(`GRANT EXECUTE ON FUNCTION auth_invites_for_user(uuid) TO snapline_app`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP FUNCTION IF EXISTS auth_invites_for_user(uuid)`);

    // Falla a propósito si alguien quedó invitado sin canjear: revertir esto con
    // usuarios sin contraseña los dejaría con una cuenta que no puede existir.
    await q.query(`ALTER TABLE app_user ALTER COLUMN password_hash SET NOT NULL`);

    await q.query(`
      ALTER TABLE membership
        DROP COLUMN invite_code_hash,
        DROP COLUMN invite_expires_at,
        DROP COLUMN invite_attempts`);
  }
}
