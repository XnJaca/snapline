import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'flag_labels.dart';

/// Las jornadas de los últimos siete días, en solo lectura.
///
/// Solo lectura a propósito: corregir horas deja rastro y es una pantalla con
/// su propio diseño; aprobar es del panel web. Acá se mira.
class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final jornadas =
        ref.watch(weekEntriesProvider(sesion.membership.id)).value ??
        const <TimeEntrySummary>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weekTitle)),
      body: jornadas.isEmpty
          ? Center(
              child: Text(
                l10n.weekEmpty,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(context.spacing.lg),
              itemCount: jornadas.length,
              separatorBuilder: (_, _) => SizedBox(height: context.spacing.md),
              itemBuilder: (context, i) => _JornadaCard(jornada: jornadas[i]),
            ),
    );
  }
}

class _JornadaCard extends StatelessWidget {
  const _JornadaCard({required this.jornada});

  final TimeEntrySummary jornada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);

    final entrada = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(jornada.clockInAt.toLocal()),
    );
    final salida = jornada.clockOutAt == null
        ? '—'
        : material.formatTimeOfDay(
            TimeOfDay.fromDateTime(jornada.clockOutAt!.toLocal()),
          );

    return Container(
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.spacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  material.formatMediumDate(jornada.clockInAt.toLocal()),
                  style: context.texts.titleSmall,
                ),
              ),
              // Cifras en columna: tabularFigures para que alineen.
              Text(
                '$entrada – $salida',
                style: context.texts.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          Wrap(
            spacing: context.spacing.xs,
            runSpacing: context.spacing.xs,
            children: [
              _estado(l10n),
              if (jornada.enConflicto)
                StatusChip(tone: StatusTone.danger, label: l10n.todayConflictTitle)
              else if (jornada.pendiente)
                StatusChip(tone: StatusTone.info, label: l10n.weekSavedOnPhone),
              for (final bandera in jornada.flags)
                StatusChip(
                  tone: StatusTone.warning,
                  label: flagLabel(l10n, bandera),
                ),
            ],
          ),
        ],
      ),
    );
  }

  StatusChip _estado(AppLocalizations l10n) => switch (jornada.status) {
    'APPROVED' => StatusChip(tone: StatusTone.success, label: l10n.weekApproved),
    'REJECTED' => StatusChip(tone: StatusTone.danger, label: l10n.weekRejected),
    _ => StatusChip(tone: StatusTone.info, label: l10n.weekPendingApproval),
  };
}

final weekEntriesProvider =
    StreamProvider.family<List<TimeEntrySummary>, String>((ref, membershipId) {
  return ref
      .watch(timeEntryRepositoryProvider)
      .watchSince(
        membershipId,
        DateTime.now().subtract(const Duration(days: 7)),
      );
});
