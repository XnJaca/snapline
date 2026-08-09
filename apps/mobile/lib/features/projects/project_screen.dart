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
      // Sin título: el nombre de la obra vive en la cabecera, a tamaño de
      // lectura. Repetirlo acá lo duplicaba y no agregaba nada.
      title: proyecto == null ? Text(l10n.projectUntitled) : null,
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
                // Desplazables si no entran, nunca apiladas en dos filas.
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                // Sin este aire la pastilla del tema toca el borde de la
                // pantalla y el divisor de abajo.
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

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.sm,
        spacing.lg,
        spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            tone: project.status.tone,
            label: project.status.label(l10n),
            icon: project.status.icon,
          ),
          SizedBox(height: spacing.lg),

          // Qué obra es: lo más grande de la pantalla.
          Text(
            project.name,
            style: context.texts.displaySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacing.xs),
          Text(
            project.customer,
            style: context.texts.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: spacing.lg),
          Divider(height: 1, color: colors.outline),
          SizedBox(height: spacing.md),

          // Dónde y con quién: el bloque de apoyo, separado del título.
          _Dato(icon: Icons.place_outlined, text: project.site),
          SizedBox(height: spacing.sm),
          _Dato(
            icon: Icons.groups_outlined,
            text: project.crew ?? l10n.projectNoCrew,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final atenuado = context.colors.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: spacing.lg, color: atenuado),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.texts.bodySmall?.copyWith(color: atenuado),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
