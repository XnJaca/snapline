import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { MoneyPipe } from '../../core/format/money.pipe';
import { PercentPipe } from '../../core/format/percent.pipe';

type ServiceItem = components['schemas']['ServiceItem'];

@Component({
  selector: 'sl-catalog',
  imports: [TranslocoModule, Page, MoneyPipe, PercentPipe],
  templateUrl: './catalog.html',
  styleUrls: ['./catalog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Catalog {
  protected readonly data = collection<ServiceItem>(() => '/service-items');

  /** El margen es la razón de que el catálogo guarde el costo. */
  protected margin(item: ServiceItem): number | null {
    if (!item.unitPriceCents || item.costCents === null || item.costCents === undefined) return null;
    return (item.unitPriceCents - item.costCents) / item.unitPriceCents;
  }
}
