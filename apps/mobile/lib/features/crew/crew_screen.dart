import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_label.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'crew_detail_screen.dart';

/// El eje Cuadrilla: una lista de cuadrillas, no una pantalla de acción.
///
/// **Siempre la lista, aunque haya una sola** — decisión de producto al
/// probarlo: entrar directo se sentía como caer en una pantalla que no se
/// pidió. El toque de más compra saber dónde se está.
class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final cuadrillas =
        ref.watch(myCrewsProvider(sesion.membership.id)).value ?? const [];

    return AppScaffold(
      title: l10n.crewTitle,
      body: cuadrillas.isEmpty
          ? EmptyState(
              icon: Icons.groups_outlined,
              message: l10n.crewNoProject,
            )
          : ListView(
              padding: EdgeInsets.all(context.spacing.lg),
              children: [
                ListLabel(label: l10n.crewPickOne),
                for (final cuadrilla in cuadrillas) ...[
                  Material(
                    color: context.colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(context.spacing.radiusMd),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(context.spacing.radiusMd),
                      ),
                      leading: Icon(
                        Icons.groups_outlined,
                        color: context.colors.onPrimaryContainer,
                      ),
                      title: Text(
                        cuadrilla.name,
                        style: context.texts.titleMedium?.copyWith(
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: context.colors.onPrimaryContainer,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CrewDetailScreen(
                            crewId: cuadrilla.id,
                            crewName: cuadrilla.name,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.spacing.sm),
                ],
              ],
            ),
    );
  }
}

final myCrewsProvider =
    StreamProvider.family<List<({String id, String name})>, String>(
        (ref, membershipId) {
  return ref.watch(timeEntryRepositoryProvider).watchMyCrews(membershipId);
});
