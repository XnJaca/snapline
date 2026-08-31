import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { MoneyPipe } from '../../core/format/money.pipe';
import { HoursPipe } from '../../core/format/hours.pipe';

type JobCostRow = components['schemas']['JobCostRowDto'];

@Component({
  selector: 'sl-reports',
  imports: [TranslocoModule, Page, MoneyPipe, HoursPipe],
  templateUrl: './reports.html',
  styleUrls: ['./reports.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Reports {
  protected readonly data = collection<JobCostRow>(() => '/reports/job-cost');

  /** Lo facturado menos la mano de obra. Sin horas aprobadas todavía no dice nada. */
  protected margin(row: JobCostRow): number | null {
    if (!row.invoicedCents) return null;
    return (row.invoicedCents - row.laborCents) / row.invoicedCents;
  }
}
