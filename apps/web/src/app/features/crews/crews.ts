import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';
import type { components } from '@snapline/contracts';
import { collection } from '../../core/api/collection';
import { Page } from '../../shared/page/page';

type Crew = components['schemas']['Crew'];

@Component({
  selector: 'sl-crews',
  imports: [TranslocoModule, Page],
  templateUrl: './crews.html',
  styleUrls: ['./crews.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Crews {
  protected readonly data = collection<Crew>(() => '/crews');

  // `/crews` embebe la membresía del capataz pero no su usuario, así que el
  // nombre de la persona no está disponible por ninguna vía del contrato.
}
