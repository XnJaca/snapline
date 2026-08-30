import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_form_field/phone_form_field.dart';

import 'core/router/app_router.dart';
import 'core/widgets/dismiss_keyboard.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/locale_store.dart';
import 'core/theme/theme_store.dart';
import 'core/theme/theme_providers.dart';
import 'core/media/media_paths.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dónde viven las fotos, una sola vez: la galería lo lee de forma síncrona
  // desde un stream y no puede esperar a un Future por cada miniatura.
  await MediaPaths.init();

  // Antes de montar nada: leer el idioma después dejaría la primera pantalla en
  // el idioma equivocado por un frame, y esa pantalla es el login.
  final elegido = await readStoredLocale();
  final tema = await readStoredThemeMode();

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => LocaleNotifier(elegido)),
        themeModeProvider.overrideWith(() => ThemeModeNotifier(tema)),
      ],
      child: const SnaplineApp(),
    ),
  );
}

class SnaplineApp extends ConsumerWidget {
  const SnaplineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(      
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(effectiveLocaleProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // Los nombres de país y los textos del selector de teléfono, en `en` y
        // `es`. Sin esto el selector sale en inglés con la app en español.
        ...PhoneFieldLocalization.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
      // Acá y no en cada pantalla: toda hoja y todo diálogo quedan cubiertos, y
      // no hay una que se olvide.
      builder: (context, child) => DismissKeyboard(child: child!),
    );
  }
}
