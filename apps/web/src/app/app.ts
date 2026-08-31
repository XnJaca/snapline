import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from './core/theme/theme.service';

@Component({
  imports: [RouterOutlet],
  selector: 'sl-root',
  styleUrls: ['./app.scss'],
  templateUrl: './app.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class App {
  // Inyectado para que el tema se aplique al arrancar, antes de la primera pantalla.
  private readonly theme = inject(ThemeService);
}
