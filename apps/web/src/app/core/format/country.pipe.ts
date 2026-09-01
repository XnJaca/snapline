import { inject, Pipe, PipeTransform } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

/**
 * El nombre del país en el idioma activo, sin mantener 22 cadenas por idioma.
 * `Intl.DisplayNames` ya los tiene.
 */
@Pipe({ name: 'slCountry' })
export class CountryPipe implements PipeTransform {
  private readonly transloco = inject(TranslocoService);

  transform(iso: string | null | undefined): string {
    if (!iso) return '';
    try {
      return new Intl.DisplayNames([this.transloco.getActiveLang()], { type: 'region' }).of(iso) ?? iso;
    } catch {
      return iso;
    }
  }
}
