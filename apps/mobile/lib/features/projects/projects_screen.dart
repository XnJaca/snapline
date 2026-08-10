import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/sync_button.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import 'all_projects_screen.dart';
import 'project_card.dart';

/// La primera pantalla del dueño: **solo lo que está en obra ahora**.
///
/// Lee de la base local y nunca de la red. El sincronizador escribe en Drift y
/// esta lista se actualiza sola; sin señal muestra lo mismo que con señal.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final obras = ref.watch(inProgressProjectsProvider);

    return AppScaffold(
      title: AppDestination.projects.label(l10n),
      actions: const [SyncButton()],
      body: Column(
        children: [
          const _Encabezado(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(syncControllerProvider.notifier).refresh(),
              // Sin spinner: la base local responde al instante, así que un
              // indicador infinito sería ruido —y cuelga cualquier test que
              // espere a que las animaciones terminen.
              child: Builder(
                builder: (context) {
                  final lista = obras.value ?? const <ProjectSummary>[];
                  return lista.isEmpty
                    ? ListView(
                        // Scrolleable igual, o no se puede tirar para refrescar.
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: spacing.xxl * 3),
                          EmptyState(
                            icon: AppDestination.projects.icon,
                            message: l10n.projectsEmptyInProgress,
                          ),
                        ],
                      )
                    : ListView.separated(
                        key: const PageStorageKey<String>('projects.inProgress'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          spacing.lg,
                          spacing.lg,
                          spacing.lg,
                          spacing.xxl,
                        ),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: spacing.md),
                        itemBuilder: (context, index) => ProjectCard(
                          project: lista[index],
                          onTap: () =>
                              context.push('/projects/${lista[index].id}'),
                        ),
                      );
                },
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
