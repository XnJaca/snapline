import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/placeholder_list.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'sample_projects.dart';

/// Las tabs de una obra. Igual que los ejes de la barra, cada una declara su
/// permiso y no se dibuja si falta.
enum ProjectTab {
  progress(permission: 'projects.read', icon: Icons.timeline),
  photos(permission: 'media.read', icon: Icons.photo_library_outlined),
  hours(permission: 'time.read', icon: Icons.schedule),
  details(permission: 'projects.read', icon: Icons.info_outline);

  const ProjectTab({required this.permission, required this.icon});

  final String permission;
  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    ProjectTab.progress => l10n.projectTabProgress,
    ProjectTab.photos => l10n.projectTabPhotos,
    ProjectTab.hours => l10n.projectTabHours,
    ProjectTab.details => l10n.projectTabDetails,
  };
}

/// El proyecto como contenedor: al entrar a una obra, toda su información se lee
/// acá adentro y no en listas globales. Un proyecto terminado muestra las mismas
/// tabs — el timeline no cambia de forma, simplemente termina.
class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    final session = ref.watch(sessionControllerProvider).value;
    final permisos = session?.membership.permissions.toSet() ?? const <String>{};
    final tabs = ProjectTab.values
        .where((tab) => permisos.contains(tab.permission))
        .toList(growable: false);

    final proyecto = sampleProjectById(projectId);

    final barra = AppBar(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        // Se puede llegar por enlace directo, y ahí no hay a dónde volver.
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppDestination.projects.route),
      ),
      title: Text(proyecto?.name(l10n) ?? l10n.projectUntitled),
      actions: [
        if (proyecto != null)
          Padding(
            padding: EdgeInsets.only(right: spacing.lg),
            child: Center(
              child: StatusChip(
                tone: proyecto.status.tone,
                label: proyecto.status.label(l10n),
              ),
            ),
          ),
      ],
      bottom: tabs.isEmpty
          ? null
          : TabBar(
              // Desplazables si no entran, nunca apiladas en dos filas.
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              // Sin este aire la pastilla del tema toca el borde de la pantalla
              // y el divisor de abajo, y deja de leerse como pastilla.
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              indicatorPadding: EdgeInsets.symmetric(
                horizontal: spacing.xs,
                vertical: spacing.sm,
              ),
              tabs: [
                for (final tab in tabs)
                  Tab(icon: Icon(tab.icon), text: tab.label(l10n)),
              ],
            ),
    );

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: barra,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.xl),
            child: Text(
              l10n.navNoAccess,
              textAlign: TextAlign.center,
              style: context.texts.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: barra,
        body: TabBarView(
          children: [
            for (final tab in tabs)
              PlaceholderList(storageKey: '$projectId.${tab.name}'),
          ],
        ),
      ),
    );
  }
}
