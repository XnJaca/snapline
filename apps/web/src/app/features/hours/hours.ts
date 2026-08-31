import { ChangeDetectionStrategy, Component, computed } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { Chip, ChipTone } from '../../shared/chip/chip';
import { DatePipe } from '../../core/format/date.pipe';
import { HoursPipe } from '../../core/format/hours.pipe';

type TimeEntry = components['schemas']['TimeEntry'];
type Project = components['schemas']['Project'];

const TONO: Record<string, ChipTone> = {
  PENDING: 'warning',
  APPROVED: 'success',
  REJECTED: 'danger',
};

@Component({
  selector: 'sl-hours',
  imports: [TranslocoModule, Page, Chip, DatePipe, HoursPipe],
  templateUrl: './hours.html',
  styleUrls: ['./hours.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Hours {
  protected readonly data = collection<TimeEntry>(() => '/time-entries');

  // `/time-entries` devuelve solo ids: el nombre de la obra se resuelve acá.
  // Quién marcó no se puede resolver de ninguna forma —no hay endpoint de
  // membresías y el listado no embebe la persona—, así que la columna no está.
  private readonly projects = collection<Project>(() => '/projects');

  private readonly porId = computed(
    () => new Map(this.projects.value().map((project) => [project.id, project.name])),
  );

  protected readonly loading = computed(() => this.data.isLoading() || this.projects.isLoading());

  protected project(entry: TimeEntry): string {
    return this.porId().get(entry.projectId) ?? '';
  }

  protected tone(status: string): ChipTone {
    return TONO[status] ?? 'neutral';
  }

  /** Sin salida el turno sigue abierto: no se muestra un total que no existe. */
  protected worked(entry: TimeEntry): number | null {
    if (!entry.clockOutAt) return null;
    const ms = new Date(entry.clockOutAt).getTime() - new Date(entry.clockInAt).getTime();
    return ms / 3_600_000 - (entry.breakMinutes ?? 0) / 60;
  }
}
