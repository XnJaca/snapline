import { ApplicationConfig, inject, provideAppInitializer, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withFetch, withInterceptors } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { routes } from './app.routes';
import { provideI18n } from './core/i18n/i18n.config';
import { apiInterceptor } from './core/api/api.interceptor';
import { Icons } from './core/icons/icons';
import { SessionService } from './core/session/session.service';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(withFetch(), withInterceptors([apiInterceptor])),
    provideAnimationsAsync(),
    provideI18n(),
    provideAppInitializer(() => inject(Icons).register()),
    // La cookie viaja sola: si hay sesión, la primera pantalla ya la tiene y
    // nadie ve un parpadeo de login.
    provideAppInitializer(() => inject(SessionService).restore()),
  ],
};
