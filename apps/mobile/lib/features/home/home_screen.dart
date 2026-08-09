import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/snapline_logo.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../l10n/app_localizations.dart';

/// Provisional: el destino del login mientras no exista el spec de la pantalla
/// de campo. Solo confirma que la sesión quedó guardada y permite salir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final session = ref.watch(sessionControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: spacing.lg,
        title: SnaplineLogo(
          // El símbolo en el color de marca; el nombre en color de texto, para
          // que la barra no compita con la acción primaria de la pantalla.
          markColor: context.colors.primary,
          color: context.colors.onSurface,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.authSignOut,
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: session == null
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeWelcome(session.user.name),
                    style: context.texts.titleLarge,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    l10n.homeCompany(session.membership.companyName),
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
