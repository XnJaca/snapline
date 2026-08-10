import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El tema que la persona eligió en **este** dispositivo.
///
/// Preferencia de interfaz, no credencial: va a `SharedPreferences`, igual que
/// el idioma y la última pestaña.
class ThemeStore {
  const ThemeStore(this._prefs);

  static const key = 'snapline.themeMode';

  final SharedPreferencesAsync _prefs;

  /// `null` es que nunca eligió: ahí manda el tema del sistema.
  Future<ThemeMode?> read() async {
    try {
      final valor = await _prefs.getString(key);
      return switch (valor) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ThemeMode mode) async {
    // Perder la preferencia no puede impedir que el tema cambie en pantalla.
    try {
      await _prefs.setString(key, mode.name);
    } catch (_) {}
  }
}

final themeStoreProvider = Provider<ThemeStore>((ref) {
  return ThemeStore(SharedPreferencesAsync());
});

/// Para `main`, que corre antes de que exista el `ProviderScope`.
Future<ThemeMode?> readStoredThemeMode() =>
    ThemeStore(SharedPreferencesAsync()).read();
