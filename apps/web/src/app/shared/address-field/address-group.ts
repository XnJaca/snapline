import { FormBuilder, FormGroup, ValidatorFn, Validators } from '@angular/forms';
import { DEFAULT_COUNTRY, USES_TWO_LETTER_STATE } from '../../core/i18n/supported-countries';

export interface AddressValue {
  line1: string;
  line2?: string | null;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

/**
 * La misma forma para la dirección de facturación del cliente y para la de la
 * propiedad: un solo tipo, un solo formulario. Ver la ficha `cliente`.
 */
export function buildAddressGroup(fb: FormBuilder, value?: Partial<AddressValue> | null): FormGroup {
  return fb.nonNullable.group({
    line1: [value?.line1 ?? '', Validators.required],
    line2: [value?.line2 ?? ''],
    city: [value?.city ?? '', Validators.required],
    // El largo lo decide el país, no el formulario: lo ajusta `AddressField`.
    state: [value?.state ?? '', Validators.required],
    postalCode: [value?.postalCode ?? '', Validators.required],
    country: [value?.country ?? DEFAULT_COUNTRY, Validators.required],
  });
}

/** `line2` vacío se manda como ausente: el contrato lo declara opcional. */
export function addressValue(group: FormGroup): AddressValue {
  const raw = group.getRawValue() as AddressValue;
  return { ...raw, line2: raw.line2?.trim() ? raw.line2.trim() : null };
}

/**
 * El código de dos letras es de Estados Unidos y Canadá. En Costa Rica la
 * provincia es "San José": exigir dos letras ahí hace imposible cargar la
 * dirección. Ver la ficha `cliente`.
 */
export function stateValidatorsFor(iso: string): ValidatorFn[] {
  return USES_TWO_LETTER_STATE.includes(iso)
    ? [Validators.required, Validators.maxLength(2)]
    : [Validators.required];
}

export function usesTwoLetterState(iso: string): boolean {
  return USES_TWO_LETTER_STATE.includes(iso);
}
