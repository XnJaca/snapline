import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { TranslocoModule } from '@jsverse/transloco';
import { SessionService } from '../../core/session/session.service';
import { Logo } from '../../core/brand/logo';

/**
 * Lo que se ve cuando el refresh silencioso falla por red. **No es la pantalla
 * de login**: mandar ahí haría creer que la sesión venció, y la URL se conserva
 * para volver exactamente a donde estaba.
 */
@Component({
  selector: 'sl-offline',
  imports: [MatButtonModule, MatProgressBarModule, TranslocoModule, Logo],
  templateUrl: './offline.html',
  styleUrls: ['./offline.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Offline {
  private readonly session = inject(SessionService);

  protected readonly retrying = signal(false);

  protected async retry(): Promise<void> {
    this.retrying.set(true);
    try {
      await this.session.restore();
    } finally {
      this.retrying.set(false);
    }
  }
}
