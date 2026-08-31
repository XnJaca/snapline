import { ChangeDetectionStrategy, Component, computed } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { Chip, ChipTone } from '../../shared/chip/chip';
import { DatePipe } from '../../core/format/date.pipe';
import { MoneyPipe } from '../../core/format/money.pipe';

type Invoice = components['schemas']['Invoice'];

const TONO: Record<string, ChipTone> = {
  DRAFT: 'neutral',
  SENT: 'info',
  PARTIAL: 'warning',
  PAID: 'success',
  OVERDUE: 'danger',
  VOID: 'neutral',
};

@Component({
  selector: 'sl-billing',
  imports: [TranslocoModule, Page, Chip, DatePipe, MoneyPipe],
  templateUrl: './billing.html',
  styleUrls: ['./billing.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Billing {
  protected readonly data = collection<Invoice>(() => '/invoices');

  /** Lo que falta cobrar: es la pregunta que trae a alguien a esta pantalla. */
  protected readonly outstanding = computed(() =>
    this.data.value().reduce((total, invoice) => total + (invoice.balanceCents ?? 0), 0),
  );

  protected tone(status: string): ChipTone {
    return TONO[status] ?? 'neutral';
  }
}
