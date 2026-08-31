import { inject, Pipe, PipeTransform } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

/**
 * Porcentaje por la capa de i18n y no por el `PercentPipe` de Angular: ese
 * formatea con `LOCALE_ID`, que acá no sigue al idioma del usuario.
 */
@Pipe({ name: 'slPercent' })
export class PercentPipe implements PipeTransform {
  private readonly transloco = inject(TranslocoService);

  transform(ratio: number | null | undefined): string {
    if (ratio === null || ratio === undefined) return '';
    return new Intl.NumberFormat(this.transloco.getActiveLang(), {
      style: 'percent',
      maximumFractionDigits: 0,
    }).format(ratio);
  }
}
