import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/placeholder_list.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'project_status_display.dart';
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
///
/// La cabecera va arriba de las tabs y no dentro del `AppBar`: de qué obra se
/// trata —nombre, cliente, dónde y en qué estado— tiene que quedar a la vista
/// al cambiar de pestaña, o el usuario pierde el contexto al segundo toque.
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
      // El nombre vive acá y no repetido abajo a tamaño gigante: a 32px se
      // llevaba toda la pantalla y dejaba el resto sin jerarquía.
      title: Text(proyecto?.name ?? l10n.projectUntitled),
    );

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: barra,
        body: EmptyState(icon: Icons.lock_outline, message: l10n.navNoAccess),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: barra,
        body: Column(
          children: [
            if (proyecto != null) _Cabecera(project: proyecto),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.outline),
                ),
              ),
              child: TabBar(
                // Repartidas en todo el ancho: son cuatro y entran siempre, y
                // alineadas a la izquierda dejaban un hueco muerto a la
                // derecha que se leía como que faltaba algo.
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
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final tab in tabs)
                    PlaceholderList(storageKey: '$projectId.${tab.name}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// De qué obra se trata. Se queda fija arriba de las tabs: es el contexto de
/// todo lo que se lee abajo.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.project});

  final SampleProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    final atenuado = colors.onSurfaceVariant;

    // Compacta a propósito: el nombre de la obra ya está en la barra, así que
    // acá solo va el contexto —de quién, en qué estado, dónde— en dos líneas.
    // Repetirlo todo a tamaño grande dejaba la pantalla pesada y sin jerarquía.
    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        0,
        spacing.lg,
        spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.customer,
                  style: context.texts.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: spacing.sm),
              StatusChip(
                tone: project.status.tone,
                label: project.status.label(l10n),
                icon: project.status.icon,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            '${project.site} · ${project.crew ?? l10n.projectNoCrew}',
            style: context.texts.bodySmall?.copyWith(color: atenuado),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
