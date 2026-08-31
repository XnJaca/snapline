import { ChangeDetectionStrategy, Component, input } from '@angular/core';

export type ChipTone = 'neutral' | 'info' | 'success' | 'warning' | 'danger';

@Component({
  selector: 'sl-chip',
  templateUrl: './chip.html',
  styleUrls: ['./chip.scss'],
  host: { '[class]': '"chip chip--" + tone()' },
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Chip {
  readonly tone = input<ChipTone>('neutral');
}
