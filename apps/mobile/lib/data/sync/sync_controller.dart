import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import 'connectivity.dart';
import 'outbox.dart';
import 'synchronizer.dart';

/// Cuándo se sincroniza.
///
/// Al entrar —porque observa la sesión—, cuando vuelve la red, apenas algo entra
/// a la bandeja, y cuando la persona tira de la lista. No hay sincronización en
/// segundo plano con la app cerrada: eso tiene su propio spec.
///
/// **Nunca lanza.** Una pantalla que se rompe porque no hay señal es justo lo
/// que esta arquitectura existe para evitar: los datos ya están en local.
class SyncController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final haySesion = ref.watch(sessionControllerProvider).value != null;

    // Observar la conectividad hace que esto se reintente solo cuando el
    // dispositivo recupera una interfaz de red. Sin esto, volver del sótano no
    // cambiaba nada hasta que alguien tocara el botón.
    final hayInterfaz = ref.watch(connectivityProvider).value ?? true;

    // Y observar la bandeja lo dispara apenas se encola algo. Sin esto, guardar
    // **con señal** dejaba la fila marcada "sin subir" hasta que alguien
    // reabriera la app o tirara de la lista, y eso se lee como que falló.
    ref.watch(pendingCountProvider);

    if (!haySesion || !hayInterfaz) return false;
    return ref.read(synchronizerProvider).sync();
  }

  /// Para el gesto de tirar hacia abajo. El resultado importa poco: si falla, la
  /// lista sigue mostrando lo que había.
  Future<void> refresh() async {
    final ok = await ref.read(synchronizerProvider).sync();
    state = AsyncData(ok);
  }
}

final syncControllerProvider = AsyncNotifierProvider<SyncController, bool>(
  SyncController.new,
);
