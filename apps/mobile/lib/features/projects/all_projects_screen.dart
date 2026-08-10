import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/project_status.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/app_localizations.dart';
import 'project_card.dart';
import 'project_status_display.dart';

/// Toda la cartera, con una pestaña por estado. Acá viven las obras cerradas,
/// las canceladas y las que todavía no arrancaron — lo que no hace falta ver
/// todos los días.
///
/// Las pestañas se desplazan porque son ocho: apiladas en dos filas se comerían
/// la pantalla que vinieron a mostrar.
class AllProjectsScreen extends ConsumerWidget {
  const AllProjectsScreen({super.key});

  static const route = '/projects/all';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    // `null` es "todos" y va primero: es la vista sin recortar.
    const estados = <ProjectStatus?>[null, ...projectStatusLifecycle];

    return DefaultTabController(
      length: estados.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          title: Text(l10n.projectsAllTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            indicatorPadding: EdgeInsets.symmetric(
              horizontal: spacing.xs,
              vertical: spacing.sm,
            ),
            tabs: [
              for (final estado in estados)
                Tab(text: estado?.label(l10n) ?? l10n.projectsFilterAll),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final estado in estados) _Lista(status: estado),
          ],
        ),
        // La acción primaria de esta pantalla, y lo único naranja sólido.
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(l10n.projectsNew),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.comingSoon)),
          ),
        ),
      ),
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.status});

  final ProjectStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final obras = ref.watch(allProjectsProvider(status));

    // Sin spinner, por lo mismo que en la cartera: la base local no hace
    // esperar y un indicador infinito cuelga los tests.
    final visibles = obras.value ?? const <ProjectSummary>[];

    return visibles.isEmpty
          ? EmptyState(
              icon: Icons.filter_list_off,
              message: l10n.projectsEmptyFiltered,
            )
          : ListView.separated(
              key: PageStorageKey<String>('projects.all.${status?.name}'),
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.lg,
                spacing.lg,
                // Aire para que la última card no quede bajo el botón de crear.
                spacing.xxl * 2,
              ),
              itemCount: visibles.length,
              separatorBuilder: (_, _) => SizedBox(height: spacing.md),
              itemBuilder: (context, index) => ProjectCard(
                project: visibles[index],
                onTap: () => context.push('/projects/${visibles[index].id}'),
              ),
            );
  }
}
