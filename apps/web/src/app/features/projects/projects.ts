import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { Chip, ChipTone } from '../../shared/chip/chip';
import { DatePipe } from '../../core/format/date.pipe';

type Project = components['schemas']['Project'];

const TONO: Record<string, ChipTone> = {
  LEAD: 'neutral',
  ESTIMATED: 'neutral',
  SCHEDULED: 'info',
  IN_PROGRESS: 'info',
  COMPLETED: 'success',
  ON_HOLD: 'warning',
  CANCELLED: 'danger',
};

@Component({
  selector: 'sl-projects',
  imports: [TranslocoModule, Page, Chip, DatePipe],
  templateUrl: './projects.html',
  styleUrls: ['./projects.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Projects {
  protected readonly data = collection<Project>(() => '/projects');

  protected tone(status: string): ChipTone {
    return TONO[status] ?? 'neutral';
  }

  protected city(project: Project): string {
    const address = project.site?.address as { city?: string } | null | undefined;
    return address?.city ?? '';
  }
}
