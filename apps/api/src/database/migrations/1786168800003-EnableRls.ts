import { MigrationInterface, QueryRunner } from 'typeorm';

// RLS en toda tabla con company_id. Sin el GUC seteado no devuelve filas. ADR-0006.
export class EnableRls1786168800003 implements MigrationInterface {
  name = 'EnableRls1786168800003';

  private static readonly TENANT_TABLES = [
    'membership', 'crew', 'crew_member', 'customer', 'site', 'project',
    'project_assignment', 'time_entry', 'time_entry_edit', 'media_asset',
    'media_tag', 'before_after_pair', 'service_item', 'tax_rate',
    'document_counter', 'estimate', 'estimate_line', 'invoice', 'invoice_line',
    'payment', 'client_access', 'project_update', 'service_offer', 'lead',
    'testimonial', 'published_project', 'social_post', 'audit_log',
  ];

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE FUNCTION app_current_company() RETURNS uuid AS $fn$
        SELECT nullif(current_setting('app.company_id', true), '')::uuid
      $fn$ LANGUAGE sql STABLE`);

    // Rol de runtime: no owner, no superuser. RLS le aplica.
    await q.query(`
      DO $do$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'snapline_app') THEN
          CREATE ROLE snapline_app LOGIN PASSWORD 'snapline_dev';
        END IF;
      END
      $do$`);

    await q.query(`GRANT USAGE ON SCHEMA public TO snapline_app`);
    await q.query(`GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO snapline_app`);
    await q.query(`GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO snapline_app`);
    await q.query(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO snapline_app`);
    await q.query(`ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO snapline_app`);

    for (const t of EnableRls1786168800003.TENANT_TABLES) {
      await q.query(`ALTER TABLE ${t} ENABLE ROW LEVEL SECURITY`);
      await q.query(`ALTER TABLE ${t} FORCE ROW LEVEL SECURITY`);
      await q.query(`
        CREATE POLICY ${t}_tenant_isolation ON ${t}
        USING (company_id = app_current_company())
        WITH CHECK (company_id = app_current_company())`);
    }
  }

  public async down(q: QueryRunner): Promise<void> {
    for (const t of EnableRls1786168800003.TENANT_TABLES) {
      await q.query(`DROP POLICY IF EXISTS ${t}_tenant_isolation ON ${t}`);
      await q.query(`ALTER TABLE ${t} NO FORCE ROW LEVEL SECURITY`);
      await q.query(`ALTER TABLE ${t} DISABLE ROW LEVEL SECURITY`);
    }
    await q.query(`DROP FUNCTION IF EXISTS app_current_company()`);
  }
}
