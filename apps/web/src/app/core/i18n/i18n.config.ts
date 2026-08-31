import { isDevMode, Provider } from '@angular/core';
import { provideTransloco } from '@jsverse/transloco';
import { HttpTranslocoLoader } from './transloco-loader';

export const SUPPORTED_LOCALES = ['en', 'es'] as const;
export type Locale = (typeof SUPPORTED_LOCALES)[number];

export const FALLBACK_LOCALE: Locale = 'en';

/**
 * Sin sesión todavía, el idioma inicial sale del navegador. Cuando exista login,
 * `user.locale` lo gana — el locale es por usuario, no por empresa.
 */
export function localeFromBrowser(): Locale {
  const tag = typeof navigator === 'undefined' ? '' : (navigator.language ?? '');
  const base = tag.split('-')[0];
  return (SUPPORTED_LOCALES as readonly string[]).includes(base) ? (base as Locale) : FALLBACK_LOCALE;
}

export function provideI18n(): Provider[] {
  return [
    provideTransloco({
      config: {
        availableLangs: [...SUPPORTED_LOCALES],
        defaultLang: localeFromBrowser(),
        fallbackLang: FALLBACK_LOCALE,
        reRenderOnLangChange: true,
        prodMode: !isDevMode(),
        // Una clave sin traducir tiene que romper el build de un vistazo, no
        // mostrarse como el nombre de la clave en la pantalla de un cliente.
        missingHandler: { logMissingKey: true, useFallbackTranslation: true },
      },
      loader: HttpTranslocoLoader,
    }),
  ];
}
