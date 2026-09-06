import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { toApiFailure } from '../../../core/api/api-failure';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { Page } from '../../../shared/page/page';
import { Customer, CustomersApi, Site } from '../../customers/customers.api';
import { SiteDialog } from '../../customers/site-dialog/site-dialog';
import { CustomerDialog, CustomerDialogResult } from '../customer-dialog/customer-dialog';
import { ProjectsApi, ProjectStatus } from '../projects.api';
import { NEW_PROJECT_STATUSES } from '../project-status';

@Component({
  selector: 'sl-project-form',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule,
    MatProgressBarModule, MatSelectModule, TranslocoModule, Page,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './project-form.html',
  styleUrls: ['./project-form.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProjectForm {
  private readonly api = inject(ProjectsApi);
  private readonly customersApi = inject(CustomersApi);
  private readonly dialog = inject(MatDialog);
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);

  protected readonly statuses = NEW_PROJECT_STATUSES;

  protected readonly customers = signal<Customer[]>([]);
  protected readonly sites = signal<Site[]>([]);
  protected readonly loadingSites = signal(false);
  protected readonly busy = signal(false);
  protected readonly error = signal<'connection' | 'gone' | 'unknown' | null>(null);

  protected readonly form = this.fb.nonNullable.group({
    customerId: ['', Validators.required],
    siteId: ['', Validators.required],
    name: ['', Validators.required],
    serviceType: [''],
    description: [''],
    startDate: [''],
    targetEndDate: [''],
    // La oficina carga el prospecto antes de que exista trabajo; el móvil, que
    // está parado en la obra, arranca en IN_PROGRESS. Ver el spec.
    status: ['LEAD' as ProjectStatus],
  });

  protected readonly customerChosen = computed(() => !!this.form.controls.customerId.value);

  /** El valor que dispara el alta en línea desde el propio desplegable. */
  protected readonly CREAR = '__crear__';

  constructor() {
    void this.loadCustomers();
  }

  private async loadCustomers(): Promise<void> {
    try {
      this.customers.set(await this.customersApi.list());
    } catch {
      this.error.set('connection');
    }
  }

  /**
   * Elegir otro cliente vacía la propiedad: es la única forma de que el par no
   * quede cruzado si alguien vuelve atrás en el formulario.
   */
  protected async onCustomer(id: string): Promise<void> {
    if (id === this.CREAR) return this.newCustomer();

    this.form.patchValue({ customerId: id, siteId: '' });
    this.sites.set([]);
    if (!id) return;

    this.loadingSites.set(true);
    try {
      this.sites.set(await this.customersApi.sites(id));
    } catch {
      this.error.set('connection');
    } finally {
      this.loadingSites.set(false);
    }
  }

  protected async newCustomer(): Promise<void> {
    const ref = this.dialog.open(CustomerDialog, {
      width: '40rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    const result = (await ref.afterClosed().toPromise()) as CustomerDialogResult | null | undefined;
    if (!result) return;

    this.customers.update((list) => [result.customer, ...list]);
    this.sites.set([result.site]);
    this.form.patchValue({ customerId: result.customer.id, siteId: result.site.id });
  }

  protected async onSite(id: string): Promise<void> {
    if (id === this.CREAR) return this.newSite();
    this.form.patchValue({ siteId: id });
  }

  protected async newSite(): Promise<void> {
    const customerId = this.form.controls.customerId.value;
    if (!customerId) return;

    const ref = this.dialog.open(SiteDialog, {
      data: { customerId },
      width: '40rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    const site = (await ref.afterClosed().toPromise()) as Site | false | undefined;
    if (!site) return;

    this.sites.update((list) => [...list, site]);
    this.form.patchValue({ siteId: site.id });
  }

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);

    const raw = this.form.getRawValue();
    const vacío = (v: string) => (v.trim() ? v.trim() : undefined);

    try {
      const saved = await this.api.create({
        customerId: raw.customerId,
        siteId: raw.siteId,
        name: raw.name.trim(),
        serviceType: vacío(raw.serviceType),
        description: vacío(raw.description),
        startDate: vacío(raw.startDate),
        targetEndDate: vacío(raw.targetEndDate),
        status: raw.status,
      });
      await this.router.navigate(['/projects', saved.id]);
    } catch (cause) {
      // Nada se limpia, y lo creado en un diálogo no se deshace: el cliente que
      // se dio de alta acá ya existe, y borrarlo sería un borrado que nadie pidió.
      const failure = toApiFailure(cause);
      if (failure.kind === 'network') this.error.set('connection');
      else if (failure.status === 404) this.error.set('gone');
      else this.error.set('unknown');
    } finally {
      this.busy.set(false);
    }
  }

  protected cancel(): void {
    void this.router.navigate(['/projects']);
  }
}
