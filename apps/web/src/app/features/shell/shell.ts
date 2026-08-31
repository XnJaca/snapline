import { ChangeDetectionStrategy, Component, computed, effect, inject, signal } from '@angular/core';
import { BreakpointObserver } from '@angular/cdk/layout';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslocoModule, TranslocoService } from '@jsverse/transloco';
import { SessionService } from '../../core/session/session.service';
import { LocaleService } from '../../core/i18n/locale.service';
import { Locale, SUPPORTED_LOCALES } from '../../core/i18n/i18n.config';
import { ThemeMode, ThemeService } from '../../core/theme/theme.service';
import { visibleAxes } from '../../core/nav/nav';
import { Logo } from '../../core/brand/logo';
import { Offline } from '../offline/offline';

const COLLAPSED_KEY = 'sl.nav-collapsed';

@Component({
  selector: 'sl-shell',
  imports: [
    RouterLink,
    RouterLinkActive,
    RouterOutlet,
    MatButtonModule,
    MatIconModule,
    MatMenuModule,
    MatTooltipModule,
    TranslocoModule,
    Logo,
    Offline,
  ],
  templateUrl: './shell.html',
  styleUrls: ['./shell.scss'],
  host: {
    '[class.shell-host--collapsed]': 'collapsed()',
    '[class.shell-host--narrow]': 'narrow()',
    '[class.shell-host--drawer]': 'drawerOpen()',
  },
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Shell {
  private readonly session = inject(SessionService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);
  private readonly transloco = inject(TranslocoService);

  protected readonly theme = inject(ThemeService);
  protected readonly user = this.session.user;
  protected readonly membership = this.session.membership;
  protected readonly locales = SUPPORTED_LOCALES;
  protected readonly modes: readonly ThemeMode[] = ['system', 'light', 'dark'];

  // El aviso de conexión vive acá y no en la raíz: la URL se conserva, y login y
  // el andamiaje de tokens siguen entrando con el API caído.
  protected readonly offline = computed(() => this.session.status() === 'offline');

  // Lo que el rol habilita, no lo que el rol es: la tabla de permisos vive en el
  // API y viaja en el login.
  protected readonly axes = computed(() => visibleAxes(this.session.permissions()));

  protected readonly narrow = toSignal(
    inject(BreakpointObserver)
      .observe('(max-width: 60rem)')
      .pipe(map((state) => state.matches)),
    { initialValue: false },
  );

  /** Ancho: la barra recordada por el usuario. Angosto: cajón sobre el contenido. */
  protected readonly collapsed = signal(this.restoreCollapsed());
  protected readonly drawerOpen = signal(false);

  protected readonly initials = computed(() => {
    const name = this.user()?.name ?? '';
    return name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? '')
      .join('');
  });

  constructor() {
    effect(() => {
      const collapsed = this.collapsed();
      try {
        localStorage.setItem(COLLAPSED_KEY, String(collapsed));
      } catch {
        // Sin persistencia la barra sigue funcionando; solo no recuerda.
      }
    });
  }

  protected toggleNav(): void {
    if (this.narrow()) this.drawerOpen.update((open) => !open);
    else this.collapsed.update((collapsed) => !collapsed);
  }

  /** En angosto el cajón tapa el contenido: elegir un eje lo cierra. */
  protected onNavigate(): void {
    this.drawerOpen.set(false);
  }

  protected activeLocale(): string {
    return this.locale.active();
  }

  protected async changeLocale(locale: Locale): Promise<void> {
    try {
      await this.locale.change(locale);
    } catch {
      // Aplicarlo sin haberlo guardado mentiría: el idioma tiene que sobrevivir
      // a la recarga, no al tab.
      this.snackBar.open(this.transloco.translate('language.failed'), undefined, { duration: 4000 });
    }
  }

  protected async logout(): Promise<void> {
    try {
      await this.session.logout();
    } catch {
      // Sin respuesta del servidor el contador no subió: esta pestaña sale, pero
      // la cookie sigue sirviendo hasta que se pueda cerrar de verdad.
      this.snackBar.open(this.transloco.translate('session.logoutFailed'), undefined, { duration: 6000 });
    } finally {
      await this.router.navigate(['/login']);
    }
  }

  private restoreCollapsed(): boolean {
    try {
      return localStorage.getItem(COLLAPSED_KEY) === 'true';
    } catch {
      return false;
    }
  }
}
