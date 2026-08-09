import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El idioma que la persona eligió en **este** dispositivo.
///
/// Es preferencia de interfaz, no credencial: va a `SharedPreferences` y no al
/// almacén seguro, igual que la última pestaña.
class LocaleStore {
  const LocaleStore(this._prefs);

  static const key = 'snapline.locale';

  final SharedPreferencesAsync _prefs;

  /// `null` es que nunca eligió: ahí manda el idioma del sistema.
  Future<Locale?> read() async {
    try {
      final code = await _prefs.getString(key);
      return code == null ? null : Locale(code);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Locale? locale) async {
    // Que falle el guardado no puede impedir que la app quede en el idioma que
    // la persona acaba de pedir.
    try {
      if (locale == null) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, locale.languageCode);
      }
    } catch (_) {}
  }
}

final localeStoreProvider = Provider<LocaleStore>((ref) {
  return LocaleStore(SharedPreferencesAsync());
});

/// Para `main`, que corre antes de que exista el `ProviderScope`.
Future<Locale?> readStoredLocale() =>
    LocaleStore(SharedPreferencesAsync()).read();
