import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { COUNTRIES, fromE164, toE164 } from '../../core/i18n/supported-countries';
import { CountryPipe } from '../../core/format/country.pipe';

/** El país se elige y el número se normaliza acá: el DTO no valida formato. */
export function buildPhoneGroup(fb: FormBuilder, e164?: string | null): FormGroup {
  const { iso, numero } = fromE164(e164);
  return fb.nonNullable.group({ country: [iso], number: [numero] });
}

export function phoneValue(group: FormGroup): string | null {
  const { country, number } = group.getRawValue() as { country: string; number: string };
  return toE164(country, number);
}

@Component({
  selector: 'sl-phone-field',
  imports: [
    ReactiveFormsModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    TranslocoModule,
    CountryPipe,
  ],
  templateUrl: './phone-field.html',
  styleUrls: ['./phone-field.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PhoneField {
  readonly group = input.required<FormGroup>();
  readonly label = input('');
  protected readonly countries = COUNTRIES;
}
