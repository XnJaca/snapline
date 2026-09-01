import { inject, Pipe, PipeTransform } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

/** Horas con dos decimales en el formato del idioma: 7,5 en es y 7.5 en en. */
@Pipe({ name: 'slHours' })
export class HoursPipe implements PipeTransform {
  private readonly transloco = inject(TranslocoService);

  transform(hours: number | null | undefined): string {
    if (hours === null || hours === undefined) return '';
    return new Intl.NumberFormat(this.transloco.getActiveLang(), {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(hours);
  }
}
