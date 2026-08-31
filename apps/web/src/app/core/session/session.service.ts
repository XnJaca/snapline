import { computed, inject, Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { finalize, map, Observable, shareReplay, tap, firstValueFrom } from 'rxjs';
import { API_BASE_URL } from '../api/api.config';
import { isNetworkFailure } from '../api/api-failure';
import { SessionMembership, SessionStatus, SessionUser, WebAuthResult } from './session.models';

@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  // En memoria y solo en memoria: nada de esto toca localStorage ni
  // sessionStorage, que es el punto entero de ADR-0014. El refresh vive en una
  // cookie httpOnly que este código no puede leer.
  private readonly access = signal<string | null>(null);
  private readonly current = signal<WebAuthResult | null>(null);
  private pending: Observable<string> | null = null;

  readonly status = signal<SessionStatus>('unknown');
  readonly user = computed<SessionUser | null>(() => this.current()?.user ?? null);
  readonly membership = computed<SessionMembership | null>(() => this.current()?.membership ?? null);
  readonly permissions = computed<string[]>(() => this.membership()?.permissions ?? []);

  accessToken(): string | null {
    return this.access();
  }

  can(permission: string): boolean {
    return this.permissions().includes(permission);
  }

  login(identifier: string, password: string): Promise<void> {
    return firstValueFrom(
      this.http
        .post<WebAuthResult>(
          `${this.base}/auth/web/login`,
          { identifier, password },
          { withCredentials: true },
        )
        .pipe(map((result) => this.adopt(result))),
    );
  }

  /**
   * Al arrancar la app. La cookie viaja sola; si no hay, no hay sesión.
   *
   * Un fallo de red deja `offline` y no `anonymous`: expulsar a login por una
   * caída de conexión haría creer que la sesión venció.
   */
  async restore(): Promise<void> {
    try {
      await firstValueFrom(this.refresh());
    } catch {
      // El estado ya lo dejó `refresh()`.
    }
  }

  /**
   * Compartido: dos llamadas que reciben 401 a la vez esperan el mismo refresh
   * en vuelo en vez de disparar dos y pisarse el token.
   */
  refresh(): Observable<string> {
    this.pending ??= this.http
      .post<WebAuthResult>(`${this.base}/auth/web/refresh`, {}, { withCredentials: true })
      .pipe(
        tap({
          next: (result) => this.adopt(result),
          error: (error: unknown) => this.forget(isNetworkFailure(error) ? 'offline' : 'anonymous'),
        }),
        map((result) => result.accessToken),
        finalize(() => (this.pending = null)),
        shareReplay({ bufferSize: 1, refCount: false }),
      );
    return this.pending;
  }

  async logout(): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(`${this.base}/auth/web/logout`, {}, { withCredentials: true }),
      );
    } finally {
      // Se olvida igual: la pestaña sale aunque el servidor no conteste. El
      // fallo sube porque sin él el contador no aumentó y la cookie sigue viva,
      // y eso hay que decírselo a quien cerró sesión.
      this.forget('anonymous');
    }
  }

  setUserLocale(locale: SessionUser['locale']): void {
    const session = this.current();
    if (session) this.current.set({ ...session, user: { ...session.user, locale } });
  }

  private adopt(result: WebAuthResult): void {
    this.access.set(result.accessToken);
    this.current.set(result);
    this.status.set('authenticated');
  }

  private forget(status: Extract<SessionStatus, 'anonymous' | 'offline'>): void {
    this.access.set(null);
    // La sesión se conserva mientras solo falla la red: el nombre y el idioma
    // siguen siendo los de quien está adentro, y volver no debería reiniciarlo.
    if (status === 'anonymous') this.current.set(null);
    this.status.set(status);
  }
}
