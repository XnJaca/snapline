import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/theme_extensions.dart';

/// Traer lo último del servidor, a mano.
///
/// Existe además del gesto de tirar hacia abajo porque un gesto no se ve: hay
/// que saber que está. La promesa del producto es que no haga falta
/// entrenamiento, y eso incluye no tener que adivinar.
///
/// Sin spinner mientras trabaja: el icono se apaga y se deshabilita. Un
/// indicador que gira sin fin deja la pantalla animándose para siempre y cuelga
/// cualquier test que espere a que las animaciones terminen.
class SyncButton extends ConsumerWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final estado = ref.watch(syncControllerProvider);
    final sincronizando = estado.isLoading;

    return IconButton(
      icon: const Icon(Icons.sync),
      tooltip: l10n.syncNow,
      color: sincronizando ? context.colors.onSurfaceVariant : null,
      onPressed: sincronizando
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);

              // Sincronizar puede tardar con señal mala: sin este aviso el
              // botón se ve muerto y la persona lo toca de nuevo.
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.syncInProgress),
                  duration: const Duration(minutes: 1),
                ),
              );
              await ref.read(syncControllerProvider.notifier).refresh();
              if (!context.mounted) return;

              messenger.hideCurrentSnackBar();
              final ok = ref.read(syncControllerProvider).value ?? false;
              messenger.showSnackBar(
                SnackBar(content: Text(ok ? l10n.syncDone : l10n.syncFailed)),
              );
            },
    );
  }
}
