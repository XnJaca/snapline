import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from './core/theme/theme.service';
import { LocaleService } from './core/i18n/locale.service';

@Component({
  imports: [RouterOutlet],
  selector: 'sl-root',
  styleUrls: ['./app.scss'],
  templateUrl: './app.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class App {
  // Inyectados para que el tema y el idioma se apliquen al arrancar, antes de la
  // primera pantalla.
  private readonly theme = inject(ThemeService);
  private readonly locale = inject(LocaleService);
}
