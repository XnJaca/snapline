import { NgTemplateOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatStepperIntl, MatStepperModule } from '@angular/material/stepper';
import { StepperIntl } from '../../../core/i18n/stepper-intl';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { TranslocoModule } from '@jsverse/transloco';
import { toApiFailure } from '../../../core/api/api-failure';
import { Page } from '../../../shared/page/page';
import { AddressField } from '../../../shared/address-field/address-field';
import { addressValue, buildAddressGroup } from '../../../shared/address-field/address-group';
import { buildPhoneGroup, PhoneField, phoneValue } from '../../../shared/phone-field/phone-field';
import { CustomersApi } from '../customers.api';

const SOURCES = ['REFERRAL', 'WEB', 'SOCIAL', 'REPEAT', 'OTHER'] as const;

@Component({
  selector: 'sl-customer-form',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatCheckboxModule, MatFormFieldModule,
    MatInputModule, MatProgressBarModule, MatSelectModule, MatStepperModule, TranslocoModule,
    NgTemplateOutlet, Page, AddressField, PhoneField,
  ],
  providers: [{ provide: MatStepperIntl, useClass: StepperIntl }, ...REQUIRED_IN_WORDS],
  templateUrl: './customer-form.html',
  styleUrls: ['./customer-form.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CustomerForm {
  private readonly api = inject(CustomersApi);
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);

  protected readonly id = inject(ActivatedRoute).snapshot.paramMap.get('id');
  protected readonly editing = computed(() => !!this.id);
  protected readonly sources = SOURCES;

  protected readonly loading = signal(!!this.id);
  protected readonly busy = signal(false);
  protected readonly error = signal<'connection' | 'gone' | 'unknown' | null>(null);

  protected readonly form = this.fb.nonNullable.group({
    displayName: ['', Validators.required],
    firstName: [''],
    lastName: [''],
    companyName: [''],
    email: ['', Validators.email],
    source: [''],
    notes: [''],
  });

  protected readonly phone = buildPhoneGroup(this.fb);
  protected readonly billing = buildAddressGroup(this.fb);
  protected readonly site = buildAddressGroup(this.fb);

  // La dirección de facturación es opcional en el dominio: deshabilitada no valida.
  protected readonly withBilling = signal(false);
  protected readonly withSite = signal(true);

  constructor() {
    this.billing.disable();
    if (this.id) void this.load(this.id);
  }

  protected toggleBilling(on: boolean): void {
    this.withBilling.set(on);
    if (on) this.billing.enable();
    else this.billing.disable();
  }

  protected toggleSite(on: boolean): void {
    this.withSite.set(on);
    if (on) this.site.enable();
    else this.site.disable();
  }

  private async load(id: string): Promise<void> {
    try {
      const customer = await this.api.get(id);
      this.form.patchValue({
        displayName: customer.displayName,
        firstName: customer.firstName ?? '',
        lastName: customer.lastName ?? '',
        companyName: customer.companyName ?? '',
        email: customer.email ?? '',
        source: customer.source ?? '',
        notes: customer.notes ?? '',
      });
      this.phone.patchValue(buildPhoneGroup(this.fb, customer.phone).getRawValue());
      if (customer.billingAddress) {
        this.billing.patchValue(customer.billingAddress as Record<string, string>);
        this.toggleBilling(true);
      }
      // Corregir no toca las propiedades: eso vive en la ficha.
      this.toggleSite(false);
    } catch (cause) {
      this.error.set(toApiFailure(cause).kind === 'network' ? 'connection' : 'gone');
    } finally {
      this.loading.set(false);
    }
  }

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    this.site.markAllAsTouched();
    this.billing.markAllAsTouched();
    if (this.form.invalid || this.site.invalid || this.billing.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);

    const raw = this.form.getRawValue();
    const vacío = (v: string) => (v.trim() ? v.trim() : undefined);
    const body = {
      displayName: raw.displayName.trim(),
      firstName: vacío(raw.firstName),
      lastName: vacío(raw.lastName),
      companyName: vacío(raw.companyName),
      email: vacío(raw.email),
      notes: vacío(raw.notes),
      source: vacío(raw.source),
      phone: phoneValue(this.phone) ?? undefined,
      billingAddress: this.withBilling() ? addressValue(this.billing) : undefined,
      ...(!this.editing() && this.withSite() ? { site: { address: addressValue(this.site) } } : {}),
    };

    try {
      const saved = this.editing()
        ? await this.api.update(this.id!, body)
        : await this.api.create(body);
      await this.router.navigate(['/customers', saved.id]);
    } catch (cause) {
      // Nada se limpia: cargar una dirección completa dos veces es lo que hace
      // que alguien deje de usar el panel.
      const failure = toApiFailure(cause);
      if (failure.kind === 'network') this.error.set('connection');
      else if (failure.status === 404) this.error.set('gone');
      else this.error.set('unknown');
    } finally {
      this.busy.set(false);
    }
  }

  protected cancel(): void {
    void this.router.navigate(this.id ? ['/customers', this.id] : ['/customers']);
  }
}
