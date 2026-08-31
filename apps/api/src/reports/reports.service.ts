import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

import { JobCostRowDto, TimesheetRowDto } from './dto/report-row.dto';

export type TimesheetRow = TimesheetRowDto;
export type JobCostRow = JobCostRowDto;

/**
 * `bigint` y `numeric` llegan como texto desde Postgres. Sin esto el contrato
 * promete un número y entrega una cadena, y el cliente suma concatenando.
 */
function num(value: unknown): number {
  return value === null || value === undefined ? 0 : Number(value);
}

@Injectable()
export class ReportsService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  /**
   * El paquete que hoy William arma a mano para el contador. Solo horas
   * APROBADAS, y con la tarifa congelada en el registro — no la vigente.
   *
   * Devuelve horas y bruto. Retenciones e impuestos los hace el contador.
   */
  async timesheet(from: string, to: string): Promise<TimesheetRow[]> {
    const rows = await this.dataSource.query<TimesheetRow[]>(
      `SELECT
         t.membership_id                                    AS "membershipId",
         u.name                                             AS "workerName",
         t.project_id                                       AS "projectId",
         p.name                                             AS "projectName",
         count(*)::int                                      AS entries,
         round(sum(
           extract(epoch FROM (t.clock_out_at - t.clock_in_at)) / 3600
           - t.break_minutes / 60.0
         )::numeric, 2)                                     AS hours,
         max(t.pay_rate_cents_snapshot)::bigint             AS "payRateCents",
         round(sum(
           (extract(epoch FROM (t.clock_out_at - t.clock_in_at)) / 3600
            - t.break_minutes / 60.0) * t.pay_rate_cents_snapshot
         ))::bigint                                         AS "grossCents",
         count(*) FILTER (WHERE cardinality(t.flags) > 0)::int AS flagged
       FROM time_entry t
       JOIN membership m ON m.id = t.membership_id
       JOIN app_user u   ON u.id = m.user_id
       JOIN project p    ON p.id = t.project_id
       WHERE t.status = 'APPROVED'
         AND t.deleted_at IS NULL
         AND t.clock_out_at IS NOT NULL
         AND t.clock_in_at >= $1::timestamptz
         AND t.clock_in_at <  $2::timestamptz
       GROUP BY t.membership_id, u.name, t.project_id, p.name
       ORDER BY u.name, p.name`,
      [from, to],
    );
    return rows.map((row) => ({
      ...row,
      entries: num(row.entries),
      hours: num(row.hours),
      payRateCents: row.payRateCents === null ? null : num(row.payRateCents),
      grossCents: row.grossCents === null ? null : num(row.grossCents),
      flagged: num(row.flagged),
    }));
  }

  /** Costo real por proyecto contra lo cotizado. */
  async jobCost(): Promise<JobCostRow[]> {
    const rows = await this.dataSource.query<JobCostRow[]>(
      `SELECT
         p.id                                        AS "projectId",
         p.name                                      AS "projectName",
         coalesce(l.labor_cents, 0)::bigint          AS "laborCents",
         coalesce(l.hours, 0)                        AS hours,
         coalesce(i.invoiced_cents, 0)::bigint       AS "invoicedCents",
         coalesce(e.estimated_cents, 0)::bigint      AS "estimatedCents"
       FROM project p
       LEFT JOIN (
         SELECT project_id,
                sum((extract(epoch FROM (clock_out_at - clock_in_at)) / 3600
                     - break_minutes / 60.0) * pay_rate_cents_snapshot) AS labor_cents,
                round(sum(extract(epoch FROM (clock_out_at - clock_in_at)) / 3600
                     - break_minutes / 60.0)::numeric, 2)               AS hours
         FROM time_entry
         WHERE status = 'APPROVED' AND deleted_at IS NULL AND clock_out_at IS NOT NULL
         GROUP BY project_id
       ) l ON l.project_id = p.id
       LEFT JOIN (
         SELECT project_id, sum(total_cents) AS invoiced_cents
         FROM invoice WHERE status <> 'VOID' AND deleted_at IS NULL
         GROUP BY project_id
       ) i ON i.project_id = p.id
       LEFT JOIN (
         SELECT project_id, sum(total_cents) AS estimated_cents
         FROM estimate WHERE status = 'ACCEPTED' AND deleted_at IS NULL
         GROUP BY project_id
       ) e ON e.project_id = p.id
       WHERE p.deleted_at IS NULL
       ORDER BY p.created_at DESC`,
    );
    return rows.map((row) => ({
      ...row,
      laborCents: num(row.laborCents),
      hours: num(row.hours),
      invoicedCents: num(row.invoicedCents),
      estimatedCents: num(row.estimatedCents),
    }));
  }
}
