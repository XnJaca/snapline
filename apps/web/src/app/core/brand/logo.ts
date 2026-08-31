import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { TranslocoModule } from '@jsverse/transloco';

/**
 * El símbolo es el cordel de tiza antes de tensarse y la línea que queda marcada
 * al soltarlo. Réplica de `brand/logo-mark.svg`, igual que `SnaplineMark` en el
 * móvil.
 *
 * El wordmark es lo **único** del panel en Bricolage Grotesque (ADR-0009).
 */
@Component({
  selector: 'sl-logo',
  imports: [TranslocoModule],
  templateUrl: './logo.html',
  styleUrls: ['./logo.scss'],
  host: { '[class.logo--stacked]': 'stacked()' },
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Logo {
  /** Símbolo arriba y nombre debajo, para cuando la marca es protagonista. */
  readonly stacked = input(false);

  /** El símbolo solo, para la barra lateral plegada. */
  readonly wordmark = input(true);
}
