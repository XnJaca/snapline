import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { TranslocoModule } from '@jsverse/transloco';
import { AddressField } from '../../../shared/address-field/address-field';
import { addressValue, buildAddressGroup } from '../../../shared/address-field/address-group';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { toApiFailure } from '../../../core/api/api-failure';
import { CustomersApi, Site } from '../customers.api';

export interface SiteDialogData {
  customerId: string;
  /** Ausente al agregar; presente al corregir. */
  site?: Site;
}

@Component({
  selector: 'sl-site-dialog',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressBarModule,
    TranslocoModule,
    AddressField,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './site-dialog.html',
  styleUrls: ['./site-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SiteDialog {
  private readonly api = inject(CustomersApi);
  private readonly fb = inject(FormBuilder);
  private readonly ref = inject(MatDialogRef<SiteDialog, boolean>);

  protected readonly data = inject<SiteDialogData>(MAT_DIALOG_DATA);
  protected readonly busy = signal(false);
  protected readonly error = signal<'connection' | 'unknown' | null>(null);

  protected readonly address = buildAddressGroup(
    this.fb,
    this.data.site?.address as Record<string, string> | undefined,
  );

  protected readonly form = this.fb.nonNullable.group({
    geofenceRadiusM: [this.data.site?.geofenceRadiusM ?? null as number | null],
  });

  protected async submit(): Promise<void> {
    this.address.markAllAsTouched();
    if (this.address.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);
    const body = { address: addressValue(this.address), ...this.form.getRawValue() };

    try {
      if (this.data.site) {
        await this.api.updateSite(this.data.customerId, this.data.site.id, body);
      } else {
        await this.api.addSite(this.data.customerId, body);
      }
      this.ref.close(true);
    } catch (cause) {
      // Lo escrito no se pierde: el diálogo queda abierto con los campos como estaban.
      this.error.set(toApiFailure(cause).kind === 'network' ? 'connection' : 'unknown');
    } finally {
      this.busy.set(false);
    }
  }

  protected cancel(): void {
    this.ref.close(false);
  }
}
