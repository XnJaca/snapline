import { inject, Pipe, PipeTransform } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

// Un `date` de Postgres llega como "2026-09-04" y `new Date()` lo lee como
// medianoche UTC: al formatearlo en un huso al oeste de Greenwich muestra el día
// anterior. Se arma en hora local, que es lo que esa fecha significa — el día de
// trabajo de una asignación no cambia según dónde esté quien mira.
const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

function parse(value: string): Date {
  if (!DATE_ONLY.test(value)) return new Date(value);
  const [year, month, day] = value.split('-').map(Number);
  return new Date(year, month - 1, day);
}

/** Fechas por la capa de i18n, nunca concatenadas a mano (regla 24). */
@Pipe({ name: 'slDate' })
export class DatePipe implements PipeTransform {
  private readonly transloco = inject(TranslocoService);

  transform(value: string | Date | null | undefined, withTime = false): string {
    if (!value) return '';
    const date = value instanceof Date ? value : parse(value);
    if (Number.isNaN(date.getTime())) return '';

    return new Intl.DateTimeFormat(this.transloco.getActiveLang(), {
      dateStyle: 'medium',
      ...(withTime ? { timeStyle: 'short' } : {}),
    }).format(date);
  }
}
