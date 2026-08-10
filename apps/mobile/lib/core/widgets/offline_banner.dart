import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/theme_extensions.dart';
import 'status_chip.dart';

/// Avisa que la app está trabajando contra lo que tiene guardado.
///
/// **Sale del último intento de sincronización, no de si hay wifi.** El
/// teléfono conectado al router de una obra sin internet dice que tiene
/// conexión, y eso sería mentirle a quien está por cargar algo.
///
/// Es una franja fija y no un cartel que pasa: es un estado, no un evento. Un
/// aviso que desaparece a los tres segundos no sirve para saber, media hora
/// después, si lo que uno cargó ya llegó.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(syncControllerProvider);

    // Mientras el primer intento está en curso no se afirma nada: decir "sin
    // conexión" antes de haberlo intentado es adivinar.
    final sinConexion = estado.hasValue && estado.value == false;
    if (!sinConexion) return const SizedBox.shrink();

    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.sm, spacing.lg, 0),
      child: StatusChip(
        tone: StatusTone.warning,
        icon: Icons.cloud_off,
        label: AppLocalizations.of(context).syncOffline,
        expand: true,
      ),
    );
  }
}
