import { TestBed } from '@angular/core/testing';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { HttpErrorResponse } from '@angular/common/http';
import { TranslocoService } from '@jsverse/transloco';
import { CrewsApi } from '../crews.api';
import { CrewMemberDialog, CrewMemberDialogData } from './crew-member-dialog';

const PERSONA = {
  id: 'm1', userId: 'u1', name: 'Carlos Ramírez', email: null, phone: null,
  locale: 'es', role: 'WORKER', status: 'ACTIVE', payRateCents: 2200,
  employmentType: 'W2', invitedAt: null, joinedAt: null, inviteExpiresAt: null,
  crew: null,
} as unknown as CrewMemberDialogData['people'][number];

/** El envelope de ADR-0011 tal como llega: el dato aparte del texto. */
const conflicto = (details: { field: string; message: string }[]) =>
  new HttpErrorResponse({
    status: 409,
    error: {
      code: 'CREW_MEMBER_OVERLAP',
      message: 'Esa persona ya pertenece a Los de Rockville en ese rango de fechas',
      details,
    },
  });

/**
 * William administra en inglés. Un mensaje compuesto en el servidor le llegaría
 * en español sin que él lo eligiera, así que la frase se arma acá y el nombre
 * de la cuadrilla viaja como dato.
 */
describe('Agregar a la cuadrilla', () => {
  function montar(error: unknown) {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: MAT_DIALOG_DATA, useValue: {
          crewId: 'cr2', crewName: 'Los de Bethesda', people: [PERSONA], current: [],
        } satisfies CrewMemberDialogData },
        { provide: MatDialogRef, useValue: { close: () => undefined } },
        { provide: CrewsApi, useValue: { addCrewMember: () => Promise.reject(error) } },
        { provide: TranslocoService, useValue: {
          translate: (key: string, params?: Record<string, unknown>) =>
            `${key}(${JSON.stringify(params ?? {})})`,
        } },
      ],
    });
    const dialogo = TestBed.runInInjectionContext(() => new CrewMemberDialog());
    const partes = dialogo as unknown as {
      form: { patchValue: (v: Record<string, string>) => void };
      submit: () => Promise<void>;
      error: () => string | null;
    };
    partes.form.patchValue({ membershipId: 'm1', fromDate: '2026-09-15' });
    return partes;
  }

  it('nombra la cuadrilla que choca sin repetir la frase del servidor', async () => {
    const d = montar(conflicto([{ field: 'crew', message: 'Los de Rockville' }]));
    await d.submit();

    expect(d.error()).toContain('crews.overlapWith');
    expect(d.error()).toContain('Los de Rockville');
    expect(d.error()).toContain('Carlos Ramírez');
    // La prosa del servidor no llega a la pantalla.
    expect(d.error()).not.toContain('ya pertenece a');
  });

  it('sin el dato cae en la frase genérica, no en la del servidor', async () => {
    const d = montar(conflicto([]));
    await d.submit();

    expect(d.error()).toContain('crews.overlap(');
    expect(d.error()).not.toContain('ya pertenece a');
  });
});
