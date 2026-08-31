import { effect, inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { TranslocoService } from '@jsverse/transloco';
import { firstValueFrom } from 'rxjs';
import { API_BASE_URL } from '../api/api.config';
import { SessionService } from '../session/session.service';
import { SessionUser } from '../session/session.models';
import { Locale } from './i18n.config';

/**
 * El panel arranca en el idioma del navegador y lo gana `user.locale` apenas hay
 * sesión: el locale es por usuario, no por empresa ni por dispositivo.
 */
@Injectable({ providedIn: 'root' })
export class LocaleService {
  private readonly transloco = inject(TranslocoService);
  private readonly session = inject(SessionService);
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  constructor() {
    effect(() => {
      const locale = this.session.user()?.locale;
      if (locale && locale !== this.transloco.getActiveLang()) {
        this.transloco.setActiveLang(locale);
      }
    });
  }

  active(): string {
    return this.transloco.getActiveLang();
  }

  /** Persiste primero: el idioma tiene que sobrevivir a la recarga, no al tab. */
  async change(locale: Locale): Promise<void> {
    await firstValueFrom(
      this.http.patch<SessionUser>(`${this.base}/auth/me/locale`, { locale }),
    );
    this.session.setUserLocale(locale);
  }
}
