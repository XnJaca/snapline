import { inject, Injectable } from '@angular/core';
import { MatIconRegistry } from '@angular/material/icon';
import { DomSanitizer } from '@angular/platform-browser';

/**
 * Los iconos son archivos propios servidos por la app, no una fuente: la de
 * Material Symbols pesa 13 MB por tres dibujos y ADR-0009 §7 no deja traerla de
 * un CDN. Cierra DEBT-0009.
 */
export const ICONS = [
  'projects', 'customers', 'crews', 'hours',
  'catalog', 'billing', 'reports', 'publish',
  'logout', 'language', 'theme', 'menu', 'brand-mark', 'check', 'edit', 'alert',
] as const;

export type IconName = (typeof ICONS)[number];

@Injectable({ providedIn: 'root' })
export class Icons {
  private readonly registry = inject(MatIconRegistry);
  private readonly sanitizer = inject(DomSanitizer);

  register(): void {
    for (const name of ICONS) {
      this.registry.addSvgIcon(
        name,
        this.sanitizer.bypassSecurityTrustResourceUrl(`/icons/${name}.svg`),
      );
    }
  }
}
