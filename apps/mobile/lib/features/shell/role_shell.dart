import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/account_button.dart';
import '../../l10n/app_localizations.dart';

/// La barra inferior y sus ramas.
///
/// Las ramas están todas declaradas en el router y son las mismas para todos;
/// lo que cambia por rol es cuáles se dibujan. `AppDestination.index` es el
/// número de rama, así que el índice visible y el de rama no coinciden: un
/// `WORKER` ve dos pestañas que son las ramas 0 y 3.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinos = ref.watch(destinationsProvider);
    if (destinos.isEmpty) return const _NoDestinations();

    final l10n = AppLocalizations.of(context);
    final seleccionado = destinos.indexWhere(
      (destino) => destino.index == navigationShell.currentIndex,
    );

    return Scaffold(
      body: navigationShell,
      // Con un solo eje no hay navegación que mostrar (SPEC-0003).
      bottomNavigationBar: destinos.length < minDestinations
          ? null
          : NavigationBar(
              selectedIndex: seleccionado < 0 ? 0 : seleccionado,
              onDestinationSelected: (indice) {
                final destino = destinos[indice];
                navigationShell.goBranch(
                  destino.index,
                  // Volver a tocar la pestaña activa regresa a su raíz.
                  initialLocation:
                      destino.index == navigationShell.currentIndex,
                );
                ref
                    .read(lastDestinationProvider.notifier)
                    .remember(destino);
              },
              destinations: [
                for (final destino in destinos)
                  NavigationDestination(
                    icon: Icon(destino.icon),
                    selectedIcon: Icon(destino.selectedIcon),
                    label: destino.label(l10n),
                    tooltip: destino.label(l10n),
                  ),
              ],
            ),
    );
  }
}

/// Un rol cuyos permisos no dejan ningún eje en pie. No pasa con los roles del
/// contrato; existe para que la app no quede sin salida si pasara.
class _NoDestinations extends StatelessWidget {
  const _NoDestinations();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(actions: const [AccountButton()]),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: Text(
            l10n.navNoAccess,
            textAlign: TextAlign.center,
            style: context.texts.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
