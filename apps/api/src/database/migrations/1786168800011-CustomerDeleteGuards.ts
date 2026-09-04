import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * El borrado de cliente es suave, así que la clave foránea no atrapa nada: la
 * fila sigue existiendo y sus obras y documentos siguen apuntando a ella. Los
 * dos invariantes viven acá y no en el servicio, que es lo que el próximo
 * camino que borre se saltaría. Ver SPEC-0009 y la ficha `cliente`.
 */
export class CustomerDeleteGuards1786168800011 implements MigrationInterface {
  name = 'CustomerDeleteGuards1786168800011';

  public async up(q: QueryRunner): Promise<void> {
    // La línea la marca lo enviado, no lo que existe: un DRAFT es editable y
    // borrable, así que todavía no es historia (regla 16).
    await q.query(`
      CREATE FUNCTION enforce_customer_no_history() RETURNS trigger AS $fn$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM project
          WHERE customer_id = NEW.id AND deleted_at IS NULL
        ) THEN
          RAISE EXCEPTION
            'el cliente tiene historia y no se borra: tiene obras'
            USING ERRCODE = 'restrict_violation';
        END IF;

        IF EXISTS (
          SELECT 1 FROM estimate
          WHERE customer_id = NEW.id AND deleted_at IS NULL AND status <> 'DRAFT'
        ) THEN
          RAISE EXCEPTION
            'el cliente tiene historia y no se borra: tiene estimados enviados'
            USING ERRCODE = 'restrict_violation';
        END IF;

        IF EXISTS (
          SELECT 1 FROM invoice
          WHERE customer_id = NEW.id AND deleted_at IS NULL AND status <> 'DRAFT'
        ) THEN
          RAISE EXCEPTION
            'el cliente tiene historia y no se borra: tiene facturas emitidas'
            USING ERRCODE = 'restrict_violation';
        END IF;

        RETURN NEW;
      END;
      $fn$ LANGUAGE plpgsql`);

    // Solo la transición de vivo a borrado. Corregir un cliente borrado, o
    // cualquier otro UPDATE, no dispara nada.
    await q.query(`
      CREATE TRIGGER customer_no_history_on_delete
      BEFORE UPDATE ON customer
      FOR EACH ROW
      WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
      EXECUTE FUNCTION enforce_customer_no_history()`);

    // La propiedad es parte del agregado —el cliente junto con las propiedades
    // donde se trabaja—, así que se va con él. `site_set_updated_at` marca la
    // fila sola, y con eso la baja viaja en el pull incremental (regla 20).
    await q.query(`
      CREATE FUNCTION cascade_customer_site_delete() RETURNS trigger AS $fn$
      BEGIN
        UPDATE site
        SET deleted_at = NEW.deleted_at
        WHERE customer_id = NEW.id AND deleted_at IS NULL;
        RETURN NULL;
      END;
      $fn$ LANGUAGE plpgsql`);

    await q.query(`
      CREATE TRIGGER customer_sites_cascade_delete
      AFTER UPDATE ON customer
      FOR EACH ROW
      WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
      EXECUTE FUNCTION cascade_customer_site_delete()`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TRIGGER IF EXISTS customer_sites_cascade_delete ON customer`);
    await q.query(`DROP TRIGGER IF EXISTS customer_no_history_on_delete ON customer`);
    await q.query(`DROP FUNCTION IF EXISTS cascade_customer_site_delete()`);
    await q.query(`DROP FUNCTION IF EXISTS enforce_customer_no_history()`);
  }
}
