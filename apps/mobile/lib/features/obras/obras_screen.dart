import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/open_in_maps.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
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

    final lista = [?conJornada, ...obras];

    return AppScaffold(
      title: l10n.navToday,
      body: lista.isEmpty
          ? EmptyState(
              icon: Icons.event_busy_outlined,
              message: l10n.todayNoAssignments,
            )
          : ListView(
              padding: EdgeInsets.all(context.spacing.lg),
              children: [
                SectionCard(
                  label: l10n.obrasSectionTiempo,
                  child: _ResumenSemanal(membershipId: membershipId),
                ),
                SizedBox(height: context.spacing.lg),
                SectionCard(
                  label: l10n.obrasSectionAsignadas,
                  padded: false,
                  child: Column(
                    children: [
                      for (final (i, obra) in lista.indexed) ...[
                        if (i > 0)
                          Divider(height: 1, color: context.colors.outline),
                        _ObraTile(
                          obra: obra,
                          conJornadaAbierta: obra.id == abierta?.projectId,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ObraScreen(obra: obra),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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

    // El mensaje va bajo el número y alineado con él, no bajo el icono:
    // suelto a la izquierda parecía un pie de página huérfano.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(context.spacing.sm),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.schedule_outlined,
            color: context.colors.onPrimaryContainer,
          ),
        ),
        SizedBox(width: context.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.obrasDuration(total.inHours, total.inMinutes % 60),
                style: context.texts.displaySmall,
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                _animoSemanal(l10n, total),
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// El ánimo rota con las horas de la semana. Nunca reprocha: quien lleva
  /// pocas horas puede estar arrancando el lunes.
  String _animoSemanal(AppLocalizations l10n, Duration total) {
    final horas = total.inHours;
    if (horas <= 0) return l10n.obrasCheerZero;
    if (horas < 8) return l10n.obrasCheerStart;
    if (horas < 20) return l10n.obrasCheerMid;
    if (horas < 40) return l10n.obrasCheerStrong;
    return l10n.obrasCheerFull;
  }
}

/// Una obra dentro de la sección: fila de ancho completo, sin marco propio —
/// el marco es el de la sección.
class _ObraTile extends StatelessWidget {
  const _ObraTile({
    required this.obra,
    required this.onTap,
    this.conJornadaAbierta = false,
  });

  final TodayProject obra;
  final VoidCallback onTap;
  final bool conJornadaAbierta;

  @override
  Widget build(BuildContext context) {
    // El container tenue del tema, nunca el naranja saturado: ese es solo de
    // la acción primaria (la regla del naranja).
    return Material(
      color: context.colors.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.construction_outlined,
                color: context.colors.onPrimaryContainer,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obra.name,
                      style: context.texts.titleMedium?.copyWith(
                        color: context.colors.onPrimaryContainer,
                      ),
                    ),
                    if (obra.address.isNotEmpty) ...[
                      SizedBox(height: context.spacing.xs),
                      Text(
                        obra.address,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                    if (conJornadaAbierta) ...[
                      SizedBox(height: context.spacing.sm),
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
                    color: context.colors.onPrimaryContainer,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: context.colors.onPrimaryContainer,
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
