import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// Guarda la sesión en Keychain (iOS) y Keystore (Android). Nunca en
/// `SharedPreferences` ni en la base local: el refresh token dura 30 días y es
/// la credencial más valiosa del dispositivo. Ver ADR-0008.
class SessionStorage {
  const SessionStorage(this._storage);

  static const _key = 'snapline.session';

  final FlutterSecureStorage _storage;

  Future<Session?> read() async {
    // Cualquier fallo acá deja la app trabada en el arranque, así que se
    // descarta lo guardado y se pide login: JSON corrupto, un modelo viejo, o
    // el propio almacén nativo caído —el Keystore de Android se invalida al
    // cambiar el bloqueo de pantalla, y ahí `read` lanza, no devuelve null—.
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return Session.decode(raw);
    } catch (_) {
      await _clearSilencioso();
      return null;
    }
  }

  /// Si el almacén está roto, borrar también puede fallar. No hay nada más que
  /// hacer, y no puede impedir que la app arranque.
  Future<void> _clearSilencioso() async {
    try {
      await clear();
    } catch (_) {}
  }

  Future<void> write(Session session) =>
      _storage.write(key: _key, value: session.encode());

  Future<void> clear() => _storage.delete(key: _key);
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // Android usa por defecto AES-GCM con la llave envuelta en RSA-OAEP, así que
  // no hace falta configurarlo. En iOS, `first_unlock` deja leer la sesión
  // después del primer desbloqueo del día: sin eso, sincronizar en segundo
  // plano con el teléfono en el bolsillo no puede acceder al token.
  return const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.watch(secureStorageProvider));
});
