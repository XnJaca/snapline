import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { httpResource } from '@angular/common/http';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { MatTabsModule } from '@angular/material/tabs';
import { TranslocoModule, TranslocoService } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { API_BASE_URL } from '../../../core/api/api.config';
import { collection } from '../../../core/api/collection';
import { toApiFailure } from '../../../core/api/api-failure';
import { SessionService } from '../../../core/session/session.service';
import { Page } from '../../../shared/page/page';
import { Chip } from '../../../shared/chip/chip';
import { DatePipe } from '../../../core/format/date.pipe';
import { PhonePipe } from '../../../core/format/phone.pipe';
import { CountryPipe } from '../../../core/format/country.pipe';
import { ConfirmDialog } from '../../../shared/confirm/confirm-dialog';
import { CustomersApi, Site } from '../customers.api';
import { SiteDialog } from '../site-dialog/site-dialog';

type Customer = components['schemas']['Customer'];
type Project = components['schemas']['Project'];
type Address = { line1?: string; line2?: string; city?: string; state?: string; postalCode?: string; country?: string };

@Component({
  selector: 'sl-customer-detail',
  imports: [
    RouterLink, MatButtonModule, MatIconModule, MatTabsModule, TranslocoModule,
    Page, Chip, DatePipe, CountryPipe, PhonePipe,
  ],
  templateUrl: './customer-detail.html',
  styleUrls: ['./customer-detail.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CustomerDetail {
  private readonly base = inject(API_BASE_URL);
  private readonly api = inject(CustomersApi);
  private readonly dialog = inject(MatDialog);
  private readonly router = inject(Router);
  private readonly session = inject(SessionService);
  private readonly transloco = inject(TranslocoService);

  protected readonly id = inject(ActivatedRoute).snapshot.paramMap.get('id') ?? '';

  protected readonly customer = httpResource<Customer>(() => `${this.base}/customers/${this.id}`);
  protected readonly sites = httpResource<Site[]>(
    () => `${this.base}/customers/${this.id}/sites`, { defaultValue: [] });

  // No hay `GET /customers/{id}/projects` ni query param: se filtra acá. Ver SPEC-0009.
  private readonly allProjects = collection<Project>(() => '/projects');
  protected readonly projects = computed(
    () => this.allProjects.value().filter((p) => p.customerId === this.id));

  protected readonly canWrite = computed(() => this.session.can('customers.write'));
  protected readonly loading = computed(() => this.customer.isLoading() || this.sites.isLoading());
  protected readonly blocked = signal<'projects' | 'documents' | null>(null);
  protected readonly gone = signal(false);

  protected address(value: unknown): Address | null {
    return (value as Address | null) ?? null;
  }

  protected async addSite(site?: Site): Promise<void> {
    const ref = this.dialog.open(SiteDialog, { data: { customerId: this.id, site } });
    if (await ref.afterClosed().toPromise()) this.sites.reload();
  }

  protected async remove(): Promise<void> {
    const t = (key: string, params?: Record<string, unknown>) => this.transloco.translate(key, params);
    const ref = this.dialog.open(ConfirmDialog, {
      data: {
        title: t('customers.deleteTitle'),
        body: t('customers.deleteBody', { name: this.customer.value()?.displayName ?? '' }),
        confirmLabel: t('customers.deleteConfirm'),
        danger: true,
      },
    });
    if (!(await ref.afterClosed().toPromise())) return;

    this.blocked.set(null);
    try {
      await this.api.remove(this.id);
      await this.router.navigate(['/customers']);
    } catch (cause) {
      const failure = toApiFailure(cause);
      if (failure.kind === 'http' && failure.code === 'CUSTOMER_HAS_HISTORY') {
        // El error no trae conteo. La ficha ya tiene las obras cargadas, así que
        // si no hay ninguna, lo que retiene son documentos.
        this.blocked.set(this.projects().length > 0 ? 'projects' : 'documents');
      } else if (failure.kind === 'http' && failure.status === 404) {
        this.gone.set(true);
      } else {
        this.blocked.set('documents');
      }
    }
  }
}
