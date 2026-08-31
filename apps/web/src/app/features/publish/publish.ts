import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';
import { DatePipe } from '../../core/format/date.pipe';

type PublishedProject = components['schemas']['PublishedProject'];

@Component({
  selector: 'sl-publish',
  imports: [TranslocoModule, Page, DatePipe],
  templateUrl: './publish.html',
  styleUrls: ['./publish.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Publish {
  protected readonly data = collection<PublishedProject>(() => '/published');
}
