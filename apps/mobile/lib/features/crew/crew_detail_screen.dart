import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/account_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'personas_tab.dart';

/// Una cuadrilla, con tabs: la gente y sus horas.
///
/// `enEje` cuando se renderiza directo en la pestaña —una sola cuadrilla, sin
/// lista intermedia—: ahí lleva el botón de cuenta, como toda pantalla de eje.
class CrewDetailScreen extends ConsumerWidget {
  const CrewDetailScreen({
    super.key,
    required this.crewId,
    required this.crewName,
    this.enEje = false,
  });

  final String crewId;
  final String crewName;
  final bool enEje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(crewName),
          automaticallyImplyLeading: !enEje,
          actions: [if (enEje) const AccountButton()],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.crewTabPeople),
              Tab(text: l10n.crewTabHours),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const PersonasTab(),
            _HorasTab(crewId: crewId),
          ],
        ),
      ),
    );
  }
}

/// El acumulado de la semana por persona, sumado de lo que ya baja al
/// teléfono. Solo lectura: aprobar sigue siendo de la oficina.
class _HorasTab extends ConsumerWidget {
  const _HorasTab({required this.crewId});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filas = ref.watch(crewWeekProvider(crewId)).value ?? const [];

    // De filas crudas a total por persona: la jornada abierta corre hasta
    // ahora, y eso no se congela en SQL.
    final totales = <String, ({String name, Duration total})>{};
    for (final fila in filas) {
      final previa = totales[fila.membershipId];
      var total = previa?.total ?? Duration.zero;
      final jornada = fila.entry;
      if (jornada != null) {
        final fin = jornada.clockOutAt ?? DateTime.now();
        total += fin.difference(jornada.clockInAt) -
            Duration(minutes: jornada.breakMinutes);
      }
      totales[fila.membershipId] = (name: fila.name, total: total);
    }

    if (totales.isEmpty) {
      return EmptyState(
        icon: Icons.schedule_outlined,
        message: l10n.crewHoursEmpty,
      );
    }

    final orden = totales.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    return ListView(
      padding: EdgeInsets.all(context.spacing.lg),
      children: [
        for (final persona in orden)
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    persona.value.name,
                    style: context.texts.titleSmall,
                  ),
                ),
                Text(
                  l10n.obrasDuration(
                    persona.value.total.inHours,
                    persona.value.total.inMinutes % 60,
                  ),
                  style: context.texts.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final crewWeekProvider = StreamProvider.family<
    List<({String membershipId, String name, TimeEntrySummary? entry})>,
    String>((ref, crewId) {
  return ref.watch(timeEntryRepositoryProvider).watchCrewWeekEntries(
        crewId,
        DateTime.now().subtract(const Duration(days: 7)),
      );
});
