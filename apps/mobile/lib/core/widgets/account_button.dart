import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../session/session_controller.dart';
import '../theme/theme_extensions.dart';

/// Quién está adentro y cómo salir. Vive en la barra de cada eje porque la
/// navegación por rol no tiene ninguna pantalla de perfil todavía.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: l10n.accountTitle,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _AccountSheet(),
      ),
    );
  }
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final session = ref.watch(sessionControllerProvider).value;
    if (session == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          0,
          spacing.lg,
          spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountSignedInAs(session.user.name),
              style: context.texts.titleLarge,
            ),
            SizedBox(height: spacing.xs),
            Text(
              l10n.accountCompany(session.membership.companyName),
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.xl),
            OutlinedButton.icon(
              // Salir no es la acción primaria de ninguna pantalla: sólida la
              // dejaría compitiendo con el naranja que sí lo es.
              icon: const Icon(Icons.logout),
              label: Text(l10n.authSignOut),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(spacing.touchTargetMin),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(sessionControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
