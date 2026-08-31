import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Avisa cuando el dispositivo **recupera** una interfaz de red.
///
/// Es un disparador, no una verdad: que haya wifi no significa que el servidor
/// conteste —el router de una obra sin internet reporta conectado igual—. Por
/// eso esto solo dispara un intento de sincronizar, y **quien decide si hay
/// conexión sigue siendo el resultado de ese intento**.
///
/// **Se expone como objeto y no solo como `StreamProvider`** porque hay dos
/// consumidores con necesidades distintas: la pantalla quiere el estado actual
/// —y para eso el provider está bien—, y el motor de sincronización necesita
/// una suscripción de **Dart**. Un `ref.listen` desde un provider que nadie
/// observa no corre nunca, y el motor es exactamente eso. Ver [syncEngineProvider].
///
/// Cada llamada a [hayInterfaz] devuelve su propio stream, así que los dos
/// reciben el estado inicial y ninguno depende del otro.
class ConnectivityWatcher {
  const ConnectivityWatcher();

  Stream<bool> hayInterfaz() async* {
    final connectivity = Connectivity();
    yield _tieneRed(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(_tieneRed);
  }
}

final connectivityWatcherProvider =
    Provider<ConnectivityWatcher>((ref) => const ConnectivityWatcher());

final connectivityProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityWatcherProvider).hayInterfaz().distinct(),
);

bool _tieneRed(List<ConnectivityResult> resultados) =>
    resultados.any((r) => r != ConnectivityResult.none);
