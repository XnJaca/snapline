import { MigrationInterface, QueryRunner } from 'typeorm';

// Por qué se aprobó o se rechazó una jornada. Hasta ahora la razón solo vivía en
// `time_entry_edit`, que ningún cliente puede leer: el pull no la baja y no tiene
// controller. Ver SPEC-0011.
export class TimeEntryDecisionReason1786168800009 implements MigrationInterface {
  name = 'TimeEntryDecisionReason1786168800009';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE time_entry ADD COLUMN decision_reason text`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE time_entry DROP COLUMN decision_reason`);
  }
}
