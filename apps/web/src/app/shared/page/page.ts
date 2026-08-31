import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { TranslocoModule } from '@jsverse/transloco';
import { KeepScroll } from '../../core/scroll/keep-scroll.directive';

/**
 * El armazón de toda pantalla del panel: encabezado propio, y los tres estados
 * que una lista servida por red siempre tiene. Ninguna pantalla los resuelve por
 * su cuenta, o terminan siete versiones distintas de "no se pudo cargar".
 */
@Component({
  selector: 'sl-page',
  imports: [MatButtonModule, MatIconModule, MatProgressBarModule, TranslocoModule, KeepScroll],
  templateUrl: './page.html',
  styleUrls: ['./page.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Page {
  readonly heading = input.required<string>();
  readonly meta = input('');
  readonly icon = input('');
  readonly loading = input(false);
  readonly failed = input(false);
  readonly empty = input(false);
  readonly emptyText = input('');

  readonly retry = output<void>();
}
