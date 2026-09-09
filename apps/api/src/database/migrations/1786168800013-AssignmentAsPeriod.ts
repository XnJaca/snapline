import { MigrationInterface, QueryRunner } from 'typeorm';

// Una cuadrilla entra a una obra y en algún momento termina su parte: eso es un
// período, no una fila por día. Nadie iba a cargar diez filas para dos semanas.
// Misma forma que crew_member, y por la misma razón.
export class AssignmentAsPeriod1786168800013 implements MigrationInterface {
  name = 'AssignmentAsPeriod1786168800013';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE project_assignment RENAME COLUMN work_date TO from_date`);
    await q.query(`ALTER TABLE project_assignment ADD COLUMN to_date date`);

    // El final no puede ser anterior al principio.
    await q.query(`
      ALTER TABLE project_assignment
        ADD CONSTRAINT project_assignment_period_ordered
        CHECK (to_date IS NULL OR to_date >= from_date)`);

    // El índice servía para buscar por día; ahora se busca por período abierto.
    await q.query(`DROP INDEX IF EXISTS idx_assignment_date`);
    await q.query(`
      CREATE INDEX idx_assignment_period
        ON project_assignment (company_id, from_date, to_date)
        WHERE deleted_at IS NULL`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP INDEX IF EXISTS idx_assignment_period`);
    await q.query(`ALTER TABLE project_assignment DROP CONSTRAINT IF EXISTS project_assignment_period_ordered`);
    await q.query(`ALTER TABLE project_assignment DROP COLUMN to_date`);
    await q.query(`ALTER TABLE project_assignment RENAME COLUMN from_date TO work_date`);
    await q.query(`CREATE INDEX idx_assignment_date ON project_assignment (company_id, work_date) WHERE deleted_at IS NULL`);
  }
}
