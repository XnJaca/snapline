import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/info_card.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'personas_tab.dart';

/// Una cuadrilla, con tabs: la gente y sus horas. Siempre llega pusheada
/// desde la lista del eje.
class CrewDetailScreen extends ConsumerWidget {
  const CrewDetailScreen({
    super.key,
    required this.crewId,
    required this.crewName,
  });

  final String crewId;
  final String crewName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(crewName),
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
        for (final persona in orden) ...[
          _PersonaHoras(name: persona.value.name, total: persona.value.total),
          SizedBox(height: context.spacing.sm),
        ],
      ],
    );
  }
}

/// Una persona y su acumulado, en card: iniciales, nombre y horas.
class _PersonaHoras extends StatelessWidget {
  const _PersonaHoras({required this.name, required this.total});

  final String name;
  final Duration total;

  String get _iniciales {
    final partes = name.trim().split(RegExp(r'\s+'));
    final letras = partes
        .take(2)
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase());
    return letras.join();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return InfoCard(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        children: [
          Container(
            width: context.spacing.xl * 2,
            height: context.spacing.xl * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              _iniciales,
              style: context.texts.titleSmall?.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Text(name, style: context.texts.titleSmall),
          ),
          Text(
            l10n.obrasDuration(total.inHours, total.inMinutes % 60),
            style: context.texts.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
