import { MigrationInterface, QueryRunner } from 'typeorm';

// El historial de estados de la obra. `project.status` guarda el ahora y pisa lo
// anterior, así que hasta acá el camino no existía en ninguna parte. Ver SPEC-0012.
export class ProjectStatusHistory1786168800011 implements MigrationInterface {
  name = 'ProjectStatusHistory1786168800011';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE project_status_change (
        id                       uuid PRIMARY KEY,
        company_id               uuid NOT NULL REFERENCES company(id),
        project_id               uuid NOT NULL REFERENCES project(id),
        from_status              project_status,
        to_status                project_status NOT NULL,
        changed_by_membership_id uuid REFERENCES membership(id),
        device_recorded_at       timestamptz NOT NULL,
        server_received_at       timestamptz NOT NULL,
        created_at               timestamptz NOT NULL DEFAULT now(),
        updated_at               timestamptz NOT NULL DEFAULT now(),
        deleted_at               timestamptz,
        CONSTRAINT status_change_is_a_change
          CHECK (from_status IS NULL OR from_status <> to_status)
      )`);

    // El hilo se lee por obra y en orden; el pull, por cursor de `updated_at`.
    await q.query(`
      CREATE INDEX project_status_change_thread
        ON project_status_change (project_id, device_recorded_at DESC)
        WHERE deleted_at IS NULL`);
    await q.query(`
      CREATE INDEX project_status_change_pull ON project_status_change (updated_at)`);

    await q.query(`ALTER TABLE project_status_change ENABLE ROW LEVEL SECURITY`);
    await q.query(`ALTER TABLE project_status_change FORCE ROW LEVEL SECURITY`);
    await q.query(`
      CREATE POLICY project_status_change_tenant_isolation ON project_status_change
      USING (company_id = app_current_company())
      WITH CHECK (company_id = app_current_company())`);

    // La bitácora comparte el enum de visibilidad con `media_asset`, que sí
    // tiene PUBLIC. Publicar al portafolio es otro acto y otra puerta: que una
    // nota no llegue ahí no puede depender del `@IsEnum` de un DTO.
    await q.query(`
      ALTER TABLE project_update
        ADD CONSTRAINT update_visibility_not_public
        CHECK (visibility IN ('INTERNAL', 'CLIENT'))`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`
      ALTER TABLE project_update DROP CONSTRAINT IF EXISTS update_visibility_not_public`);
    await q.query(`
      DROP POLICY IF EXISTS project_status_change_tenant_isolation ON project_status_change`);
    await q.query(`DROP TABLE IF EXISTS project_status_change`);
  }
}
