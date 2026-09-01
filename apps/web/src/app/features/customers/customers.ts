import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { SessionService } from '../../core/session/session.service';
import { Page } from '../../shared/page/page';
import { DatePipe } from '../../core/format/date.pipe';
import { PhonePipe } from '../../core/format/phone.pipe';
import { filterCustomers } from './customers.filter';

type Customer = components['schemas']['Customer'];

@Component({
  selector: 'sl-customers',
  imports: [
    RouterLink,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    TranslocoModule,
    Page,
    DatePipe,
    PhonePipe,
  ],
  templateUrl: './customers.html',
  styleUrls: ['./customers.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Customers {
  private readonly session = inject(SessionService);

  protected readonly data = collection<Customer>(() => '/customers');
  protected readonly query = signal('');

  /** El contador lee y no escribe: no se le dibuja un botón que da 403. */
  protected readonly canWrite = computed(() => this.session.can('customers.write'));

  protected readonly filtered = computed(() => filterCustomers(this.data.value(), this.query()));

  /** Vacío por filtro y vacío de verdad no son lo mismo y no se dicen igual. */
  protected readonly emptyByFilter = computed(
    () => this.data.value().length > 0 && this.filtered().length === 0,
  );
}
