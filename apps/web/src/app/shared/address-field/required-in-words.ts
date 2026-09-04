import { Provider } from '@angular/core';
import { MAT_FORM_FIELD_DEFAULT_OPTIONS } from '@angular/material/form-field';

/**
 * Lo obligatorio se dice con palabras en el label —`{campo} (obligatorio)`—, que
 * es la convención que el móvil fijó. El asterisco de Material la duplicaba.
 *
 * Va por pantalla y no en `app.config` a propósito: declararlo global arrastra
 * el chunk de `form-field` al bundle inicial, y la pantalla de entrada no lo
 * necesita.
 */
export const REQUIRED_IN_WORDS: Provider[] = [
  { provide: MAT_FORM_FIELD_DEFAULT_OPTIONS, useValue: { hideRequiredMarker: true } },
];
