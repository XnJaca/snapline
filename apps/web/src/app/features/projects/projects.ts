import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { collection } from '../../core/api/collection';
import { SessionService } from '../../core/session/session.service';
import { Page } from '../../shared/page/page';
import { Chip, ChipTone } from '../../shared/chip/chip';
import { DatePipe } from '../../core/format/date.pipe';
import { projectDates } from './project-dates';
import { projectStatusTone, PROJECT_STATUSES } from './project-status';
import type { Project } from './projects.api';
import { ALL_STATUSES, filterProjects, StatusFilter } from './projects.filter';

@Component({
  selector: 'sl-projects',
  imports: [
    RouterLink, MatButtonModule, MatFormFieldModule, MatIconModule, MatInputModule, MatSelectModule,
    TranslocoModule, Page, Chip,
  ],
  providers: [DatePipe],
  templateUrl: './projects.html',
  styleUrls: ['./projects.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Projects {
  private readonly session = inject(SessionService);
  private readonly fecha = inject(DatePipe);

  protected readonly data = collection<Project>(() => '/projects');
  protected readonly query = signal('');
  protected readonly status = signal<StatusFilter>(ALL_STATUSES);

  protected readonly all = ALL_STATUSES;
  protected readonly statuses = PROJECT_STATUSES;

  /** Quien solo lee no encuentra un botón que lo lleve a un 403. */
  protected readonly canWrite = computed(() => this.session.can('projects.write'));

  protected readonly filtered = computed(
    () => filterProjects(this.data.value(), this.query(), this.status()),
  );

  /**
   * Los tres vacíos se dicen distinto: no hay obras todavía, ninguna coincide con
   * lo buscado, o ninguna está en ese estado. El tercero es el que más confunde
   * si se muestra el texto genérico.
   */
  protected readonly emptyBySearch = computed(
    () => this.data.value().length > 0 && this.filtered().length === 0 && !!this.query().trim(),
  );

  protected readonly emptyByStatus = computed(
    () => this.data.value().length > 0 && this.filtered().length === 0
      && !this.query().trim() && this.status() !== ALL_STATUSES,
  );

  protected tone(status: string): ChipTone {
    return projectStatusTone(status);
  }

  /**
   * El rango se arma con una clave por caso y no concatenando: el separador y el
   * orden son parte del texto traducible (regla 24).
   */
  protected dates(project: Project): { key: string; params: Record<string, string> } | null {
    return projectDates(project, (iso) => this.fecha.transform(iso));
  }

  protected city(project: Project): string {
    const address = project.site?.address as { city?: string } | null | undefined;
    return address?.city ?? '';
  }
}
