import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatCardModule } from '@angular/material/card';
import { TranslocoModule, TranslocoService } from '@jsverse/transloco';
import { ThemeMode, ThemeService } from '../../core/theme/theme.service';
import { Locale, SUPPORTED_LOCALES } from '../../core/i18n/i18n.config';

interface Swatch {
  readonly label: string;
  readonly bg: string;
  readonly fg: string;
}

@Component({
  selector: 'sl-dev-tokens',
  imports: [MatButtonModule, MatButtonToggleModule, MatCardModule, TranslocoModule],
  templateUrl: './dev-tokens.html',
  styleUrls: ['./dev-tokens.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DevTokens {
  private readonly transloco = inject(TranslocoService);
  protected readonly theme = inject(ThemeService);

  protected readonly locales = SUPPORTED_LOCALES;
  protected readonly modes: readonly ThemeMode[] = ['system', 'light', 'dark'];

  // Los nombres son los de M3 porque es lo que theme-overrides recibe: comprobar
  // el token con otro nombre no comprobaría el token.
  protected readonly roles: readonly Swatch[] = [
    { label: 'primary', bg: '--mat-sys-primary', fg: '--mat-sys-on-primary' },
    { label: 'primary-container', bg: '--mat-sys-primary-container', fg: '--mat-sys-on-primary-container' },
    { label: 'surface', bg: '--mat-sys-surface', fg: '--mat-sys-on-surface' },
    { label: 'surface-variant', bg: '--mat-sys-surface-variant', fg: '--mat-sys-on-surface' },
    { label: 'background', bg: '--mat-sys-background', fg: '--mat-sys-on-background' },
    { label: 'error', bg: '--mat-sys-error', fg: '--mat-sys-on-error' },
    { label: 'error-container', bg: '--mat-sys-error-container', fg: '--mat-sys-on-error-container' },
  ];

  // Lo que M3 no nombra y sale como variable propia. Ver ADR-0013 §3.
  protected readonly ownRoles: readonly Swatch[] = [
    { label: 'warning-container', bg: '--sl-warning-container', fg: '--sl-on-warning-container' },
    { label: 'success-container', bg: '--sl-success-container', fg: '--sl-on-success-container' },
  ];

  protected readonly spacing = [1, 2, 3, 4, 5, 6];
  protected readonly radii = ['sm', 'md', 'lg'];
  protected readonly touchTargets = ['min', 'primary', 'field'];

  protected get activeLang(): string {
    return this.transloco.getActiveLang();
  }

  protected setLang(locale: Locale): void {
    this.transloco.setActiveLang(locale);
  }
}
