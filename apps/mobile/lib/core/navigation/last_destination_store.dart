import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_destination.dart';

/// La última pestaña usada, para volver a ella al reabrir.
///
/// No va al almacén seguro a propósito: es una preferencia de interfaz, no una
/// credencial. La sesión sigue siendo lo único que vive en Keychain.
class LastDestinationStore {
  const LastDestinationStore(this._prefs);

  static const _key = 'snapline.nav.lastDestination';

  final SharedPreferencesAsync _prefs;

  /// `null` si nunca se guardó, si el almacén falla, o si el nombre guardado ya
  /// no existe en esta versión de la app. En los tres casos se abre en el
  /// primer eje del rol, que siempre es un destino válido.
  Future<AppDestination?> read() async {
    try {
      final raw = await _prefs.getString(_key);
      return raw == null ? null : AppDestination.fromName(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AppDestination destination) async {
    // Perder la preferencia no puede tumbar la navegación.
    try {
      await _prefs.setString(_key, destination.name);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }
}

final lastDestinationStoreProvider = Provider<LastDestinationStore>((ref) {
  return LastDestinationStore(SharedPreferencesAsync());
});
