import { TestBed } from '@angular/core/testing';
import { TranslocoService } from '@jsverse/transloco';
import { DatePipe } from './date.pipe';

/**
 * Un `date` de Postgres no lleva hora ni zona, y leerlo como UTC lo corre un día
 * en todo huso al oeste de Greenwich: el día de trabajo de una asignación pasaba
 * a ser el anterior para quien mira desde América.
 */
describe('DatePipe', () => {
  let pipe: DatePipe;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        DatePipe,
        { provide: TranslocoService, useValue: { getActiveLang: () => 'es' } },
      ],
    });
    pipe = TestBed.inject(DatePipe);
  });

  it('una fecha sin hora conserva su día', () => {
    expect(pipe.transform('2026-09-04')).toContain('4');
    expect(pipe.transform('2026-01-01')).toContain('1');
  });

  it('el 1 de enero no retrocede a diciembre', () => {
    expect(pipe.transform('2026-01-01')).not.toContain('2025');
  });

  it('un timestamp con zona se sigue formateando como antes', () => {
    expect(pipe.transform('2026-09-04T15:30:00.000Z')).toBeTruthy();
  });

  it('vacío y nulo no rompen', () => {
    expect(pipe.transform(null)).toBe('');
    expect(pipe.transform('')).toBe('');
    expect(pipe.transform('no es fecha')).toBe('');
  });
});
