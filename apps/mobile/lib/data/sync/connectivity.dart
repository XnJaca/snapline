import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Avisa cuando el dispositivo **recupera** una interfaz de red.
///
/// Es un disparador, no una verdad: que haya wifi no significa que el servidor
/// conteste —el router de una obra sin internet reporta conectado igual—. Por
/// eso esto solo dispara un intento de sincronizar, y **quien decide si hay
/// conexión sigue siendo el resultado de ese intento**.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  Stream<bool> hayInterfaz() async* {
    yield _tieneRed(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(_tieneRed);
  }

  return hayInterfaz().distinct();
});

bool _tieneRed(List<ConnectivityResult> resultados) =>
    resultados.any((r) => r != ConnectivityResult.none);
