import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { FormGroup, ReactiveFormsModule } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { COUNTRIES } from '../../core/i18n/supported-countries';
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
}
