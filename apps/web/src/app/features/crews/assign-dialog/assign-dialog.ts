import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { collection } from '../../../core/api/collection';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { toApiFailure } from '../../../core/api/api-failure';
import { CrewsApi, Project } from '../crews.api';
import { isOpenProject } from '../../projects/project-status';

export interface AssignDialogData {
  crewId: string;
  crewName: string;
}

@Component({
  selector: 'sl-assign-dialog',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule,
    MatInputModule, MatProgressBarModule, MatSelectModule, TranslocoModule,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './assign-dialog.html',
  styleUrls: ['./assign-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AssignDialog {
  private readonly api = inject(CrewsApi);
  private readonly fb = inject(FormBuilder);
  private readonly ref = inject(MatDialogRef<AssignDialog, boolean>);

  protected readonly data = inject<AssignDialogData>(MAT_DIALOG_DATA);
  protected readonly busy = signal(false);
  protected readonly error = signal<string | null>(null);

  private readonly projects = collection<Project>(() => '/projects');
  // Una obra cerrada, cancelada o en pausa no recibe cuadrillas nuevas.
  protected readonly open = computed(
    () => this.projects.value().filter((p) => isOpenProject(p.status)));

  // La asignación es un período abierto: entra un día y sigue ahí hasta que
  // alguien marque que terminó. La obra ya tiene su fecha de inicio, así que
  // esa es la propuesta y no el día de hoy.
  protected readonly form = this.fb.nonNullable.group({
    projectId: ['', Validators.required],
    fromDate: [new Date().toISOString().slice(0, 10), Validators.required],
  });

  protected pickProject(projectId: string): void {
    const start = this.projects.value().find((p) => p.id === projectId)?.startDate;
    if (start) this.form.controls.fromDate.setValue(String(start).slice(0, 10));
  }

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);
    const { projectId, fromDate } = this.form.getRawValue();

    try {
      await this.api.assign(projectId, { crewId: this.data.crewId, fromDate });
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
