import { inject, Pipe, PipeTransform } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

/**
 * Centavos a moneda con el formato del idioma activo. Nunca `$` + número: eso
 * es un bug esperando al primer cliente que no facture en dólares (regla 24).
 *
 * La moneda es constante porque el modelo no tiene una: la empresa factura en
 * Maryland. Cuando exista el campo, sale de ahí y no de acá.
 */
const CURRENCY = 'USD';

@Pipe({ name: 'slMoney' })
export class MoneyPipe implements PipeTransform {
  private readonly transloco = inject(TranslocoService);

  transform(cents: number | null | undefined): string {
    if (cents === null || cents === undefined) return '';
    return new Intl.NumberFormat(this.transloco.getActiveLang(), {
      style: 'currency',
      currency: CURRENCY,
    }).format(cents / 100);
  }
}
