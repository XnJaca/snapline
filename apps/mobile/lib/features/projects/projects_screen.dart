import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';
import 'all_projects_screen.dart';
import 'project_card.dart';
import 'sample_projects.dart';

/// La primera pantalla del dueño: **solo lo que está en obra ahora**.
///
/// Nada de filtros ni de estados acá. Lo que abre todos los días muestra una
/// sola cosa; el resto de la cartera —lo agendado, lo pausado, lo cerrado— vive
/// en su propia pantalla, a un toque.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final enProceso = inProgressSampleProjects;

    return AppScaffold(
      title: AppDestination.projects.label(l10n),
      body: Column(
        children: [
          const _Encabezado(),
          Expanded(
            child: enProceso.isEmpty
                ? EmptyState(
                    icon: AppDestination.projects.icon,
                    message: l10n.projectsEmptyInProgress,
                  )
                : ListView.separated(
                    key: const PageStorageKey<String>('projects.inProgress'),
                    padding: EdgeInsets.fromLTRB(
                      spacing.lg,
                      spacing.lg,
                      spacing.lg,
                      spacing.xxl,
                    ),
                    itemCount: enProceso.length,
                    separatorBuilder: (_, _) => SizedBox(height: spacing.md),
                    itemBuilder: (context, index) => ProjectCard(
                      project: enProceso[index],
                      onTap: () => context.push(enProceso[index].location),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Qué se está viendo y cómo salir de ahí.
///
/// Va en su propia franja, con el fondo de la barra y un borde abajo: suelto
/// sobre el fondo de la lista no se lee como parte de la interfaz, flota.
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.sm, spacing.sm),
      child: Row(
        // Arriba y no al centro: el título puede irse a dos líneas y el botón
        // quedaría descolgado a media altura.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: spacing.md),
              child: Text(
                l10n.projectsInProgressTitle,
                style: context.texts.titleLarge,
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          TextButton.icon(
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right),
            label: Text(l10n.projectsViewAll),
            onPressed: () => context.push(AllProjectsScreen.route),
          ),
        ],
      ),
    );
  }
}
