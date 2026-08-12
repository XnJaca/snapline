import { MigrationInterface, QueryRunner } from 'typeorm';

// El gate del photo release sale del producto (DEBT-0005). En su lugar queda el
// EXIF, que es la fuga concreta: publicar una foto sin limpiar deja las
// coordenadas de la casa del cliente en el portafolio.
export class ReplacePhotoReleaseWithExifGate1786168800008 implements MigrationInterface {
  name = 'ReplacePhotoReleaseWithExifGate1786168800008';

  public async up(q: QueryRunner): Promise<void> {
    // Los triggers antes que la columna: al revés, las funciones quedan leyendo
    // una columna que ya no existe.
    await q.query(`DROP TRIGGER IF EXISTS media_asset_photo_release ON media_asset`);
    await q.query(`DROP TRIGGER IF EXISTS published_project_release ON published_project`);
    await q.query(`DROP FUNCTION IF EXISTS enforce_photo_release()`);
    await q.query(`DROP FUNCTION IF EXISTS enforce_publish_release()`);

    await q.query(`ALTER TABLE customer DROP CONSTRAINT IF EXISTS customer_release_doc_fk`);
    await q.query(`
      ALTER TABLE customer
        DROP COLUMN photo_release_granted_at,
        DROP COLUMN photo_release_document_id`);

    await q.query(`
      CREATE FUNCTION enforce_exif_stripped() RETURNS trigger AS $fn$
      BEGIN
        IF NEW.visibility <> 'PUBLIC' OR NEW.kind <> 'PHOTO' THEN
          RETURN NEW;
        END IF;
        IF NEW.exif_stripped_at IS NULL THEN
          RAISE EXCEPTION
            'media_asset %: no puede ser PUBLIC sin limpiar el EXIF', NEW.id
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $fn$ LANGUAGE plpgsql`);

    await q.query(`
      CREATE TRIGGER media_asset_exif_stripped
      BEFORE INSERT OR UPDATE OF visibility ON media_asset
      FOR EACH ROW EXECUTE FUNCTION enforce_exif_stripped()`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TRIGGER IF EXISTS media_asset_exif_stripped ON media_asset`);
    await q.query(`DROP FUNCTION IF EXISTS enforce_exif_stripped()`);

    await q.query(`
      ALTER TABLE customer
        ADD COLUMN photo_release_granted_at  timestamptz,
        ADD COLUMN photo_release_document_id uuid`);
    await q.query(`ALTER TABLE customer ADD CONSTRAINT customer_release_doc_fk
      FOREIGN KEY (photo_release_document_id) REFERENCES media_asset(id)`);

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
  }
}
