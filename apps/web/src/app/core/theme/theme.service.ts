import { Injectable, effect, signal } from '@angular/core';

export type ThemeMode = 'system' | 'light' | 'dark';

const STORAGE_KEY = 'sl.theme';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  readonly mode = signal<ThemeMode>(this.restore());

  constructor() {
    effect(() => this.apply(this.mode()));
  }

  set(mode: ThemeMode): void {
    this.mode.set(mode);
  }

  private restore(): ThemeMode {
    // Puede tirar en modo privado de Safari, y quedarse sin tema por eso sería peor
    // que no recordar la preferencia.
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored === 'light' || stored === 'dark' ? stored : 'system';
    } catch {
      return 'system';
    }
  }

  /**
   * `system` borra el atributo en vez de escribir un valor: sin él manda
   * `prefers-color-scheme`, que es lo que el SCSS ya resuelve.
   */
  private apply(mode: ThemeMode): void {
    const root = document.documentElement;
    if (mode === 'system') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', mode);

    try {
      if (mode === 'system') localStorage.removeItem(STORAGE_KEY);
      else localStorage.setItem(STORAGE_KEY, mode);
    } catch {
      // Sin persistencia el tema sigue aplicado; solo no sobrevive la recarga.
    }
  }
}
