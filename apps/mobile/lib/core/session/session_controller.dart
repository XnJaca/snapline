import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/login_dto.dart';
import '../../data/local/app_database.dart';
import '../network/api_client.dart';
import '../network/api_failure.dart';
import 'session.dart';
import 'session_storage.dart';

/// La sesión del dispositivo. `null` significa que no hay ninguna guardada.
///
/// Ojo con lo que **no** hace: un login fallido no toca este estado, y un
/// refresh fallido tampoco borra la sesión. Solo `signOut` la elimina.
class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.read(sessionStorageProvider).read();

  /// Lanza [ApiFailure] si falla. El estado solo cambia cuando hay éxito, así
  /// que un intento fallido no deja la app sin sesión.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      final result = await ref
          .read(authClientProvider)
          .authLogin(
            body: LoginDto(identifier: identifier, password: password),
          );

      final session = Session.fromAuthResult(result, DateTime.now());
      await ref.read(sessionStorageProvider).write(session);
      state = AsyncData(session);
    } on ApiFailure {
      rethrow;
    } catch (error) {
      throw ApiFailure.from(error);
    }
  }

  /// Guarda la sesión renovada por el interceptor.
  Future<void> renew(Session session) async {
    await ref.read(sessionStorageProvider).write(session);
    state = AsyncData(session);
  }

  /// Borra también lo local: dejar la cartera de una empresa en el teléfono
  /// para que la vea la siguiente sesión es el mismo problema que un
  /// `company_id` mal filtrado, pero del lado del dispositivo.
  Future<void> signOut() async {
    await ref.read(sessionStorageProvider).clear();
    await ref.read(appDatabaseProvider).wipe();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// Hay sesión guardada, aunque su token esté vencido: sin red igual se entra.
final hasSessionProvider = Provider<bool>((ref) {
  return ref.watch(sessionControllerProvider).value != null;
});
