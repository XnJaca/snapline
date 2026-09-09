import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { toApiFailure } from '../../../core/api/api-failure';
import { Crew, CrewsApi, Member } from '../crews.api';
import { CREW_COLORS } from '../../../core/brand/crew-colors';

export interface CrewDialogData {
  crew?: Crew;
  /** Para elegir encargado. Vacío si quien mira no tiene `members.manage`. */
  people: Member[];
}

@Component({
  selector: 'sl-crew-dialog',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule,
    MatInputModule, MatProgressBarModule, MatSelectModule, TranslocoModule,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './crew-dialog.html',
  styleUrls: ['./crew-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CrewDialog {
  private readonly api = inject(CrewsApi);
  private readonly fb = inject(FormBuilder);
  private readonly ref = inject(MatDialogRef<CrewDialog, boolean>);

  protected readonly data = inject<CrewDialogData>(MAT_DIALOG_DATA);
  protected readonly busy = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly colors = CREW_COLORS;

  protected readonly form = this.fb.nonNullable.group({
    name: [this.data.crew?.name ?? '', Validators.required],
    color: [this.data.crew?.color ?? CREW_COLORS[0] as string],
    foremanMembershipId: [this.data.crew?.foreman?.membershipId ?? null as string | null],
  });

  // Ser encargado no es un rol ni un permiso: cualquiera puede serlo, el dueño
  // incluido. Ver la ficha de dominio de cuadrilla.
  protected readonly candidates = this.data.people.filter((m) => m.status !== 'INACTIVE');

  protected pick(color: string): void {
    this.form.controls.color.setValue(color);
  }

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);
    const raw = this.form.getRawValue();
    const body = {
      name: raw.name,
      color: raw.color,
      ...(raw.foremanMembershipId ? { foremanMembershipId: raw.foremanMembershipId } : {}),
    };

    try {
      if (this.data.crew) await this.api.updateCrew(this.data.crew.id, body);
      else await this.api.createCrew(body);
      this.ref.close(true);
    } catch (cause) {
      this.error.set(
        toApiFailure(cause).kind === 'network' ? 'form.error.connection' : 'form.error.unknown',
      );
    } finally {
      this.busy.set(false);
    }
  }

  protected cancel(): void {
    this.ref.close(false);
  }
}
