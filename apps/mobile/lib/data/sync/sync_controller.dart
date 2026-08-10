import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import 'synchronizer.dart';

/// Cuándo se sincroniza.
///
/// Al entrar —porque observa la sesión— y cuando la persona tira de la lista.
/// No hay sincronización en segundo plano con la app cerrada: eso tiene su
/// propio spec.
///
/// **Nunca lanza.** Una pantalla que se rompe porque no hay señal es justo lo
/// que esta arquitectura existe para evitar: los datos ya están en local.
class SyncController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final hay = ref.watch(sessionControllerProvider).value != null;
    if (!hay) return false;
    return ref.read(synchronizerProvider).pull();
  }

  /// Para el gesto de tirar hacia abajo. El resultado importa poco: si falla, la
  /// lista sigue mostrando lo que había.
  Future<void> refresh() async {
    final ok = await ref.read(synchronizerProvider).pull();
    state = AsyncData(ok);
  }
}

final syncControllerProvider = AsyncNotifierProvider<SyncController, bool>(
  SyncController.new,
);
