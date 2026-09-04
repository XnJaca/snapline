import { ChangeDetectionStrategy, Component, effect, input, signal } from '@angular/core';
import { FormGroup, ReactiveFormsModule } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { COUNTRIES } from '../../core/i18n/supported-countries';
import { stateValidatorsFor, usesTwoLetterState } from './address-group';
import { CountryPipe } from '../../core/format/country.pipe';

@Component({
  selector: 'sl-address-field',
  imports: [
    ReactiveFormsModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    TranslocoModule,
    CountryPipe,
  ],
  templateUrl: './address-field.html',
  styleUrls: ['./address-field.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AddressField {
  readonly group = input.required<FormGroup>();
  protected readonly countries = COUNTRIES;

  /**
   * El código de dos letras es de Estados Unidos y Canadá. En Costa Rica la
   * provincia es "San José": exigir dos letras ahí hace imposible cargar la
   * dirección.
   */
  protected readonly twoLetterState = signal(false);

  constructor() {
    effect((onCleanup) => {
      const group = this.group();
      const country = group.get('country');
      const state = group.get('state');

      const aplicar = (iso: string): void => {
        this.twoLetterState.set(usesTwoLetterState(iso));
        state?.setValidators(stateValidatorsFor(iso));
        state?.updateValueAndValidity({ emitEvent: false });
      };
      aplicar((country?.value as string) ?? '');

      const subPaís = country?.valueChanges.subscribe((iso: string) => aplicar(iso));

      // Solo el código se guarda en mayúsculas: `md` y `MD` son el mismo estado.
      // Pasar "San José" a mayúsculas sería romper el dato, no normalizarlo.
      const subEstado = state?.valueChanges.subscribe((valor: string) => {
        if (!this.twoLetterState()) return;
        const mayúsculas = (valor ?? '').toUpperCase();
        if (mayúsculas !== valor) state.setValue(mayúsculas, { emitEvent: false });
      });

      onCleanup(() => {
        subPaís?.unsubscribe();
        subEstado?.unsubscribe();
      });
    });
  }
}
