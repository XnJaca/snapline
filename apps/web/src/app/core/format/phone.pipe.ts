import { Pipe, PipeTransform } from '@angular/core';
import { dialOf, fromE164 } from '../i18n/supported-countries';

/**
 * El teléfono se **guarda** en E.164 y se **muestra** legible. Mostrar
 * `+15559876543` en una tabla obliga a contar dígitos con el dedo.
 */
@Pipe({ name: 'slPhone' })
export class PhonePipe implements PipeTransform {
  transform(e164: string | null | undefined): string {
    if (!e164) return '';

    const { iso, numero } = fromE164(e164);
    const dial = dialOf(iso);

    // Norteamérica tiene una forma que la gente reconoce de un vistazo.
    if (dial === '1' && numero.length === 10) {
      return `+1 (${numero.slice(0, 3)}) ${numero.slice(3, 6)}-${numero.slice(6)}`;
    }

    const grupos = numero.match(/\d{1,3}/g) ?? [numero];
    return `+${dial} ${grupos.join(' ')}`;
  }
}
