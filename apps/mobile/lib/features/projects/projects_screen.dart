import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'sample_projects.dart';

/// La cartera de obras. Andamiaje hasta que la lista tenga su spec: las filas
/// son sintéticas, pero navegan de verdad — sin eso no se puede verificar que
/// entrar a un proyecto abra su contenedor de tabs.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return AppScaffold(
      title: AppDestination.projects.label(l10n),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: StatusChip(
              tone: StatusTone.info,
              label: l10n.comingSoon,
              expand: true,
            ),
          ),
          Expanded(
            child: ListView.separated(
              key: const PageStorageKey<String>('projects'),
              padding: EdgeInsets.only(bottom: spacing.xxl),
              itemCount: sampleProjects.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: context.colors.outline),
              itemBuilder: (context, index) {
                final proyecto = sampleProjects[index];
                return ListTile(
                  minTileHeight: spacing.touchTargetPrimary,
                  leading: Icon(
                    AppDestination.projects.icon,
                    color: context.colors.onSurfaceVariant,
                  ),
                  title: Text(proyecto.name(l10n)),
                  subtitle: Text(proyecto.status.label(l10n)),
                  trailing: const Icon(Icons.chevron_right),
                  // `push` y no `go`: la obra se abre encima de la cartera, y
                  // volver tiene que devolver a la lista donde estaba.
                  onTap: () => context.push(proyecto.location),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
