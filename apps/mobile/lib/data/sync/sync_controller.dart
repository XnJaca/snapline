import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import 'connectivity.dart';
import 'media_uploader.dart';
import 'outbox.dart';
import 'synchronizer.dart';

/// Corre las sincronizaciones, de a una, sin importar quién las pida.
///
/// Existe separado del controlador por el ciclo de vida, no por gusto. El
/// disparo de la bandeja necesita sobrevivir dos cosas que Riverpod 3 le hace a
/// un provider con dependencias: **pausarlo** cuando ningún widget visible lo
/// escucha —y se escribe justo desde pantallas pushed, con el shell tapado— y
/// **cancelarle sus recursos al invalidarse** aunque el rebuild quede diferido,
/// que es lo que mataba la suscripción apenas la sesión o la red cambiaban.
class SyncEngine {
  SyncEngine(this._ref);

  final Ref _ref;
  Future<bool>? _enCurso;
  bool _otraVez = false;

  /// Una sincronización a la vez.
  ///
  /// Lo que llega mientras corre no abre otra en paralelo ni se pierde: marca
  /// una pasada más al terminar. Sin esto, el arranque disparaba tres a la vez
  /// —sesión, red y bandeja llegan casi juntas— y cada una empujaba el mismo
  /// lote.
  Future<bool> sincronizar() {
    final actual = _enCurso;
    if (actual != null) {
      _otraVez = true;
      return actual;
    }
    final corrida = _correr();
    _enCurso = corrida;
    return corrida.whenComplete(() => _enCurso = null);
  }

  Future<bool> _correr() async {
    // Al momento de correr, no al construir nada: el disparo llega con los
    // providers pausados, donde cualquier estado capturado puede ser viejo.
    final haySesion = _ref.read(sessionControllerProvider).value != null;
    final hayInterfaz = _ref.read(connectivityProvider).value ?? true;
    if (!haySesion || !hayInterfaz) return false;

    var ok = await _ref.read(synchronizerProvider).sync();
    while (_otraVez) {
      _otraVez = false;
      ok = await _ref.read(synchronizerProvider).sync();
    }
    // Los binarios van después de un push que ENTRÓ: el registro del asset
    // tiene que existir en el servidor antes de pedir dónde subirlo, y con el
    // push caído cada intento sería un 404 seguro.
    if (ok) await _ref.read(mediaUploaderProvider).subirPendientes();
    return ok;
  }
}

/// El dueño de la suscripción a la bandeja.
///
/// **Sin ningún `ref.watch`, a propósito**: sin dependencias no hay
/// invalidación, y sin invalidación Riverpod no cancela la suscripción ni la
/// pausa. Es lo que garantiza que encolar dispare el push aunque el shell esté
/// tapado por la pantalla que acaba de guardar.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(ref);
  final sub = ref.read(outboxProvider).watchPendingCount().listen((n) {
    if (n > 0) engine.sincronizar();
  });
  ref.onDispose(sub.cancel);

  // Volver la red, por la misma razón y con el mismo remedio. Estaba solo en
  // el `watch` de [SyncController], que se pausa con el shell tapado: salir del
  // sótano con la obra abierta no disparaba nada hasta volver atrás y tirar de
  // la lista.
  //
  // Y va con una suscripción de Dart, como la bandeja: un `ref.listen` acá no
  // sirve —este provider no tiene observadores, y sin ellos sus suscripciones
  // de Riverpod no corren—. Se comprobó, no se dedujo.
  final red = ref
      .read(connectivityWatcherProvider)
      .hayInterfaz()
      .distinct()
      .listen((hay) {
    if (hay) engine.sincronizar();
  });
  ref.onDispose(red.cancel);

  return engine;
});

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

    // Se observa para el estado que se muestra —el botón y el aviso de sin
    // señal—, no como disparo: tapado el shell esto se pausa. Quien garantiza
    // que volver la red sincronice es [syncEngineProvider].
    final hayInterfaz = ref.watch(connectivityProvider).value ?? true;

    // `read` y no `watch`: el motor no debe quedar atado al ciclo de vida de
    // este provider, que se pausa y se invalida. Ver [syncEngineProvider].
    final engine = ref.read(syncEngineProvider);

    if (!haySesion || !hayInterfaz) return false;
    return engine.sincronizar();
  }

  /// Para el gesto de tirar hacia abajo. El resultado importa poco: si falla, la
  /// lista sigue mostrando lo que había.
  Future<void> refresh() async {
    final ok = await ref.read(syncEngineProvider).sincronizar();
    state = AsyncData(ok);
  }
}

final syncControllerProvider = AsyncNotifierProvider<SyncController, bool>(
  SyncController.new,
);
