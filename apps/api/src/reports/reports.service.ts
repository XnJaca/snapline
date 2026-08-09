import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

export interface TimesheetRow {
  membershipId: string;
  workerName: string;
  projectId: string;
  projectName: string;
  entries: number;
  hours: number;
  payRateCents: number | null;
  grossCents: number | null;
  flagged: number;
}

export interface JobCostRow {
  projectId: string;
  projectName: string;
  laborCents: number;
  hours: number;
  invoicedCents: number;
  estimatedCents: number;
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
  timesheet(from: string, to: string): Promise<TimesheetRow[]> {
    return this.dataSource.query(
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
  }

  /** Costo real por proyecto contra lo cotizado. */
  jobCost(): Promise<JobCostRow[]> {
    return this.dataSource.query(
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
  }
}
