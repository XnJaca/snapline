import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule, TranslocoService } from '@jsverse/transloco';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { toApiFailure } from '../../../core/api/api-failure';
import { CrewMember, CrewsApi, Member } from '../crews.api';

export interface CrewMemberDialogData {
  crewId: string;
  crewName: string;
  people: Member[];
  current: CrewMember[];
}

@Component({
  selector: 'sl-crew-member-dialog',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule,
    MatInputModule, MatProgressBarModule, MatSelectModule, TranslocoModule,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './crew-member-dialog.html',
  styleUrls: ['./crew-member-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CrewMemberDialog {
  private readonly api = inject(CrewsApi);
  private readonly fb = inject(FormBuilder);
  private readonly ref = inject(MatDialogRef<CrewMemberDialog, boolean>);
  private readonly transloco = inject(TranslocoService);

  protected readonly data = inject<CrewMemberDialogData>(MAT_DIALOG_DATA);
  protected readonly busy = signal(false);
  protected readonly error = signal<string | null>(null);

  /** Quien ya está adentro con tramo abierto no se ofrece de nuevo. */
  protected readonly candidates = this.data.people.filter((person) =>
    person.status !== 'INACTIVE'
    && !this.data.current.some((cm) => cm.membershipId === person.id && !cm.toDate));

  protected readonly form = this.fb.nonNullable.group({
    membershipId: ['', Validators.required],
    // Hoy como valor propuesto: es lo que pasa el 90% de las veces.
    fromDate: [new Date().toISOString().slice(0, 10), Validators.required],
  });

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);
    const raw = this.form.getRawValue();

    try {
      await this.api.addCrewMember(this.data.crewId, raw);
      this.ref.close(true);
    } catch (cause) {
      const failure = toApiFailure(cause);
      if (failure.kind === 'network') {
        this.error.set(this.transloco.translate('form.error.connection'));
        return;
      }
      // El solape lo impide un constraint de exclusión de la base, no el
      // formulario. El servidor es el único que sabe **cuál** es la otra
      // cuadrilla, pero manda el nombre en `details`: la frase se arma acá, en
      // el idioma de quien mira.
      if (failure.kind === 'http' && failure.code === 'CREW_MEMBER_OVERLAP') {
        const otra = failure.details.find((d) => d.field === 'crew')?.message;
        const quien = this.candidates.find((p) => p.id === raw.membershipId)?.name ?? '';
        this.error.set(this.transloco.translate(
          otra ? 'crews.overlapWith' : 'crews.overlap',
          { name: quien, crew: otra },
        ));
        return;
      }
      this.error.set(this.transloco.translate('form.error.unknown'));
    } finally {
      this.busy.set(false);
    }
  }

  protected cancel(): void {
    this.ref.close(false);
  }
}
