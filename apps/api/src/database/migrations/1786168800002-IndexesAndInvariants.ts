import { MigrationInterface, QueryRunner } from 'typeorm';

// Invariantes que no se pueden expresar como CHECK de una sola fila.
export class IndexesAndInvariants1786168800002 implements MigrationInterface {
  name = 'IndexesAndInvariants1786168800002';

  public async up(q: QueryRunner): Promise<void> {
    // ------------------------------------------------------------- índices
    for (const t of ['membership', 'crew', 'crew_member', 'customer', 'site', 'project',
      'project_assignment', 'time_entry', 'media_asset', 'service_item', 'estimate',
      'invoice', 'payment', 'project_update', 'lead', 'social_post']) {
      await q.query(`CREATE INDEX idx_${t}_company ON ${t} (company_id) WHERE deleted_at IS NULL`);
    }
    // client_access se revoca, no se borra.
    await q.query(`CREATE INDEX idx_client_access_company ON client_access (company_id) WHERE revoked_at IS NULL`);
    await q.query(`CREATE INDEX idx_client_access_live ON client_access (customer_id) WHERE revoked_at IS NULL`);

    await q.query(`CREATE INDEX idx_project_customer ON project (customer_id) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_project_status ON project (company_id, status) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_media_project ON media_asset (project_id) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_media_visibility ON media_asset (company_id, visibility) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_time_entry_project ON time_entry (project_id) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_time_entry_membership ON time_entry (membership_id, clock_in_at DESC) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_time_entry_pending ON time_entry (company_id, status) WHERE status = 'PENDING' AND deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_assignment_date ON project_assignment (company_id, work_date) WHERE deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_invoice_open ON invoice (company_id, due_at) WHERE status IN ('SENT','PARTIAL','OVERDUE') AND deleted_at IS NULL`);
    await q.query(`CREATE INDEX idx_published_live ON published_project (company_id) WHERE unpublished_at IS NULL`);

    await q.query(`CREATE UNIQUE INDEX uq_media_checksum ON media_asset (project_id, checksum) WHERE deleted_at IS NULL`);

    // Exactamente un OWNER activo por empresa.
    await q.query(`CREATE UNIQUE INDEX uq_membership_single_owner ON membership (company_id)
      WHERE role = 'OWNER' AND status = 'ACTIVE' AND deleted_at IS NULL`);

    // Un solo registro de tiempo abierto por persona.
    await q.query(`CREATE UNIQUE INDEX uq_time_entry_single_open ON time_entry (membership_id)
      WHERE clock_out_at IS NULL AND deleted_at IS NULL`);

    // ------------------------------------------------------ updated_at auto
    await q.query(`
      CREATE FUNCTION set_updated_at() RETURNS trigger AS $fn$
      BEGIN
        NEW.updated_at = now();
        RETURN NEW;
      END;
      $fn$ LANGUAGE plpgsql`);

    await q.query(`
      DO $do$
      DECLARE t text;
      BEGIN
        FOR t IN
          SELECT c.table_name FROM information_schema.columns c
          WHERE c.table_schema = 'public' AND c.column_name = 'updated_at'
        LOOP
          EXECUTE format(
            'CREATE TRIGGER %I_set_updated_at BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
        END LOOP;
      END
      $do$`);

    // --------------------------------------------------- photo release
    await q.query(`
      CREATE FUNCTION enforce_photo_release() RETURNS trigger AS $fn$
      DECLARE granted timestamptz;
      BEGIN
        IF NEW.visibility <> 'PUBLIC' THEN
          RETURN NEW;
        END IF;
        SELECT c.photo_release_granted_at INTO granted
        FROM project p JOIN customer c ON c.id = p.customer_id
        WHERE p.id = NEW.project_id;
        IF granted IS NULL THEN
          RAISE EXCEPTION
            'media_asset %: no puede ser PUBLIC, el cliente no otorgó photo release', NEW.id
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $fn$ LANGUAGE plpgsql`);

    await q.query(`
      CREATE TRIGGER media_asset_photo_release
      BEFORE INSERT OR UPDATE OF visibility ON media_asset
      FOR EACH ROW EXECUTE FUNCTION enforce_photo_release()`);

    await q.query(`
      CREATE FUNCTION enforce_publish_release() RETURNS trigger AS $fn$
      DECLARE granted timestamptz;
      BEGIN
        SELECT c.photo_release_granted_at INTO granted
        FROM project p JOIN customer c ON c.id = p.customer_id
        WHERE p.id = NEW.project_id;
        IF granted IS NULL THEN
          RAISE EXCEPTION
            'project %: no se puede publicar, el cliente no otorgó photo release', NEW.project_id
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $fn$ LANGUAGE plpgsql`);

    await q.query(`
      CREATE TRIGGER published_project_release
      BEFORE INSERT ON published_project
      FOR EACH ROW EXECUTE FUNCTION enforce_publish_release()`);

    // ------------------------------------------ las horas no se borran
    await q.query(`
      CREATE FUNCTION block_time_entry_delete() RETURNS trigger AS $fn$
      BEGIN
        RAISE EXCEPTION
          'time_entry no se borra: usar deleted_at y registrar el cambio en time_entry_edit'
          USING ERRCODE = 'restrict_violation';
      END;
      $fn$ LANGUAGE plpgsql`);

    await q.query(`
      CREATE TRIGGER time_entry_no_hard_delete
      BEFORE DELETE ON time_entry
      FOR EACH ROW EXECUTE FUNCTION block_time_entry_delete()`);

    // ------------------------- numeración por empresa con lock de fila
    await q.query(`
      CREATE FUNCTION next_document_number(p_company uuid, p_doc_type counter_doc_type)
      RETURNS bigint AS $fn$
      DECLARE n bigint;
      BEGIN
        INSERT INTO document_counter (company_id, doc_type, next_number)
        VALUES (p_company, p_doc_type, 1)
        ON CONFLICT (company_id, doc_type) DO NOTHING;

        UPDATE document_counter
        SET next_number = next_number + 1
        WHERE company_id = p_company AND doc_type = p_doc_type
        RETURNING next_number - 1 INTO n;

        RETURN n;
      END;
      $fn$ LANGUAGE plpgsql`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TRIGGER IF EXISTS time_entry_no_hard_delete ON time_entry`);
    await q.query(`DROP TRIGGER IF EXISTS published_project_release ON published_project`);
    await q.query(`DROP TRIGGER IF EXISTS media_asset_photo_release ON media_asset`);
    await q.query(`DROP FUNCTION IF EXISTS next_document_number(uuid, counter_doc_type)`);
    await q.query(`DROP FUNCTION IF EXISTS block_time_entry_delete()`);
    await q.query(`DROP FUNCTION IF EXISTS enforce_publish_release()`);
    await q.query(`DROP FUNCTION IF EXISTS enforce_photo_release()`);
    await q.query(`DROP FUNCTION IF EXISTS set_updated_at() CASCADE`);
  }
}
