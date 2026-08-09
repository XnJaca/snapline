import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import 'app_destination.dart';
import 'last_destination_store.dart';

/// Los ejes que ve la sesión actual. Sale de la sesión guardada, así que se
/// arma igual sin red.
final destinationsProvider = Provider<List<AppDestination>>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) return const [];
  return destinationsFor(session.membership);
});

/// La última pestaña usada. Se lee del disco una sola vez, al arrancar: el
/// router espera en el splash hasta que esté, o la app abriría en el primer eje
/// y saltaría a otro un frame después.
class LastDestinationController extends AsyncNotifier<AppDestination?> {
  @override
  Future<AppDestination?> build() =>
      ref.read(lastDestinationStoreProvider).read();

  Future<void> remember(AppDestination destination) async {
    state = AsyncData(destination);
    await ref.read(lastDestinationStoreProvider).write(destination);
  }
}

final lastDestinationProvider =
    AsyncNotifierProvider<LastDestinationController, AppDestination?>(
      LastDestinationController.new,
    );

/// A dónde entra la app: la última pestaña, si el rol de ahora todavía la
/// tiene, y si no el primer eje.
///
/// La validación importa porque el teléfono es de la empresa y lo usa más de
/// una persona: William deja abierto Facturación, entra Carlos y esa pestaña ya
/// no existe para él.
///
/// Es una función y no un provider derivado a propósito. El router la llama
/// desde su `redirect`, que corre en pleno build; un provider que observe a
/// otro se invalida en cascada justo ahí y termina programando un refresh del
/// scope en medio del build.
AppDestination? initialDestination({
  required List<AppDestination> destinations,
  required AppDestination? last,
}) {
  if (destinations.isEmpty) return null;
  return destinations.contains(last) ? last : destinations.first;
}
