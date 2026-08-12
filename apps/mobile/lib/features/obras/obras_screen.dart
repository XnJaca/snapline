import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/open_in_maps.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'obra_screen.dart';

/// El eje Obras: una lista de lugares, no una pantalla de acción.
///
/// La decisión de producto de SPEC-0009, textual: "es mejor que muestre las
/// obras, el usuario toque la obra, y ahí pueda ver en tabs lo que
/// corresponde". Arriba, el resumen de la semana propia.
class ObrasScreen extends ConsumerWidget {
  const ObrasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final membershipId = sesion.membership.id;
    final obras =
        ref.watch(todayProjectsProvider(membershipId)).value ??
        const <TodayProject>[];

    // La obra con la jornada abierta entra a la lista aunque ya no tenga
    // asignación hoy — quedó abierta ayer y hoy lo cambiaron de obra. Sin
    // esto, el camino a marcar la salida dependería de la asignación, y
    // cerrar la jornada podría fallar (regla 9).
    final abierta = ref.watch(openEntryProvider(membershipId)).value;
    TodayProject? conJornada;
    if (abierta != null && !obras.any((o) => o.id == abierta.projectId)) {
      conJornada = ref.watch(placeProvider(abierta.projectId)).value;
    }

    return AppScaffold(
      title: l10n.navToday,
      body: obras.isEmpty && conJornada == null
          ? EmptyState(
              icon: Icons.event_busy_outlined,
              message: l10n.todayNoAssignments,
            )
          : ListView(
              padding: EdgeInsets.all(context.spacing.lg),
              children: [
                _ResumenSemanal(membershipId: membershipId),
                SizedBox(height: context.spacing.lg),
                for (final obra in [?conJornada, ...obras]) ...[
                  _ObraCard(
                    obra: obra,
                    conJornadaAbierta: obra.id == abierta?.projectId,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ObraScreen(obra: obra),
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

/// Cuánto se trabajó esta semana, sumado de las jornadas locales. La abierta
/// cuenta hasta ahora.
class _ResumenSemanal extends ConsumerWidget {
  const _ResumenSemanal({required this.membershipId});

  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jornadas =
        ref.watch(weekEntriesProvider(membershipId)).value ??
        const <TimeEntrySummary>[];

    var total = Duration.zero;
    for (final j in jornadas) {
      final fin = j.clockOutAt ?? DateTime.now();
      total += fin.difference(j.clockInAt) - Duration(minutes: j.breakMinutes);
    }

    return Row(
      children: [
        Icon(
          Icons.schedule_outlined,
          size: context.spacing.xl,
          color: context.colors.onSurfaceVariant,
        ),
        SizedBox(width: context.spacing.sm),
        Text(
          l10n.obrasWeekSummary(
            l10n.obrasDuration(total.inHours, total.inMinutes % 60),
          ),
          style: context.texts.titleSmall,
        ),
      ],
    );
  }
}

class _ObraCard extends StatelessWidget {
  const _ObraCard({
    required this.obra,
    required this.onTap,
    this.conJornadaAbierta = false,
  });

  final TodayProject obra;
  final VoidCallback onTap;
  final bool conJornadaAbierta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(context.spacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.spacing.radiusMd),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.construction_outlined,
                color: context.colors.onSurfaceVariant,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(obra.name, style: context.texts.titleMedium),
                    if (obra.address.isNotEmpty) ...[
                      SizedBox(height: context.spacing.xs),
                      Text(
                        obra.address,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (conJornadaAbierta) ...[
                      SizedBox(height: context.spacing.xs),
                      StatusChip(
                        tone: StatusTone.success,
                        label: AppLocalizations.of(context).obrasAbiertaAca,
                      ),
                    ],
                  ],
                ),
              ),
              if (obra.address.isNotEmpty || obra.hasLocation)
                IconButton(
                  tooltip: AppLocalizations.of(context).todayOpenInMaps,
                  onPressed: () => openInMaps(
                    lat: obra.lat,
                    lng: obra.lng,
                    address: obra.address,
                  ),
                  icon: Icon(
                    Icons.directions_outlined,
                    color: context.colors.onSurfaceVariant,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: context.colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final todayProjectsProvider =
    StreamProvider.family<List<TodayProject>, String>((ref, membershipId) {
  return ref.watch(timeEntryRepositoryProvider).watchTodayProjects(membershipId);
});

final openEntryProvider =
    StreamProvider.family<TimeEntrySummary?, String>((ref, membershipId) {
  return ref.watch(timeEntryRepositoryProvider).watchOpen(membershipId);
});

final placeProvider =
    StreamProvider.family<TodayProject?, String>((ref, projectId) {
  return ref.watch(timeEntryRepositoryProvider).watchPlace(projectId);
});

final weekEntriesProvider =
    StreamProvider.family<List<TimeEntrySummary>, String>((ref, membershipId) {
  return ref
      .watch(timeEntryRepositoryProvider)
      .watchSince(membershipId, DateTime.now().subtract(const Duration(days: 7)));
});
