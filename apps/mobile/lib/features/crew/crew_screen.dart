import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'crew_detail_screen.dart';

/// El eje Cuadrilla: una lista de cuadrillas, no una pantalla de acción.
///
/// Con una sola —el caso normal— se entra directo, sin lista intermedia que
/// solo tenga un renglón.
class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final cuadrillas =
        ref.watch(myCrewsProvider(sesion.membership.id)).value ?? const [];

    if (cuadrillas.length == 1) {
      return CrewDetailScreen(
        crewId: cuadrillas.single.id,
        crewName: cuadrillas.single.name,
        enEje: true,
      );
    }

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
                Text(l10n.crewPickOne, style: context.texts.titleSmall),
                SizedBox(height: context.spacing.sm),
                for (final cuadrilla in cuadrillas) ...[
                  Material(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(context.spacing.radiusMd),
                    child: ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(cuadrilla.name),
                      trailing: const Icon(Icons.chevron_right),
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
