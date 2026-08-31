import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { DatePipe } from '../../core/format/date.pipe';

type Customer = components['schemas']['Customer'];

@Component({
  selector: 'sl-customers',
  imports: [TranslocoModule, Page, DatePipe],
  templateUrl: './customers.html',
  styleUrls: ['./customers.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Customers {
  protected readonly data = collection<Customer>(() => '/customers');
}
