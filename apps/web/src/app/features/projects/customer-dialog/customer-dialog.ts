import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { TranslocoModule } from '@jsverse/transloco';
import { AddressField } from '../../../shared/address-field/address-field';
import { addressValue, buildAddressGroup } from '../../../shared/address-field/address-group';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { toApiFailure } from '../../../core/api/api-failure';
import { Customer, CustomersApi, Site } from '../../customers/customers.api';

export interface CustomerDialogResult {
  customer: Customer;
  site: Site;
}

/**
 * El alta mínima para que una obra se pueda crear: cómo se llama el cliente y
 * dónde se trabaja. Correo, teléfono, origen y facturación se llenan después
 * desde la ficha, que es dueña de esa pantalla (SPEC-0009).
 *
 * Lo que crea acá **ya existe** al cerrar: son dos escrituras contra el API, no
 * un borrador que se guarda junto con la obra.
 */
@Component({
  selector: 'sl-customer-dialog',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule,
    MatInputModule, MatProgressBarModule, TranslocoModule, AddressField,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './customer-dialog.html',
  styleUrls: ['./customer-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CustomerDialog {
  private readonly api = inject(CustomersApi);
  private readonly fb = inject(FormBuilder);
  private readonly ref = inject(MatDialogRef<CustomerDialog, CustomerDialogResult | null>);

  protected readonly busy = signal(false);
  protected readonly error = signal<'connection' | 'unknown' | null>(null);

  /**
   * El alta son dos llamadas: se crea el cliente y después se lee su propiedad.
   * Si la segunda falla, la primera ya ocurrió: sin recordarlo, reintentar daba
   * de alta un segundo cliente con el mismo nombre, y SPEC-0009 no deja borrar
   * un cliente al que ya se le colgó una obra.
   */
  private readonly creado = signal<Customer | null>(null);

  protected readonly form = this.fb.nonNullable.group({
    displayName: ['', Validators.required],
  });

  protected readonly address = buildAddressGroup(this.fb);

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    this.address.markAllAsTouched();
    if (this.form.invalid || this.address.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);

    try {
      const customer = this.creado() ?? await this.api.create({
        displayName: this.form.getRawValue().displayName.trim(),
        site: { address: addressValue(this.address) },
      });
      this.creado.set(customer);

      // El alta devuelve el cliente, no su propiedad: hay que leerla para poder
      // dejarla elegida en el formulario de la obra.
      const [site] = await this.api.sites(customer.id);
      this.ref.close({ customer, site });
    } catch (cause) {
      // Nada se limpia: el diálogo queda abierto con los campos como estaban.
      this.error.set(toApiFailure(cause).kind === 'network' ? 'connection' : 'unknown');
    } finally {
      this.busy.set(false);
    }
  }

  protected cancel(): void {
    this.ref.close(null);
  }
}
