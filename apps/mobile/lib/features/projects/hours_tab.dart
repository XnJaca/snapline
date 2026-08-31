import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import '../today/flag_labels.dart';
import 'reject_shift_sheet.dart';

/// Las horas de la obra: cuántas lleva y quién las hizo.
///
/// **Toda la vida de la obra, no la semana.** Las vistas de campo cuentan los
/// últimos 7 días porque a quien trabaja le importa su semana; acá la pregunta
/// es cuánto lleva puesto este trabajo (SPEC-0011).
///
/// Es también una bandeja: quien puede aprobar decide desde acá, y sin señal
/// también — la decisión se encola y el servidor la resuelve contra el estado
/// que el teléfono tenía a la vista.
class HoursTab extends ConsumerStatefulWidget {
  const HoursTab({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<HoursTab> createState() => _HoursTabState();
}

class _HoursTabState extends ConsumerState<HoursTab> {
  /// Cuál jornada está expandida. **Una sola**: cada una expandida muestra su
  /// "Aprobar" en naranja sólido, y dos naranjas a la vez dejan de señalar cuál
  /// es la acción (la regla del naranja, `apps/mobile/CLAUDE.md`).
  String? _expandida;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final jornadas = ref.watch(jornadasDeLaObraProvider(widget.projectId));

    final sesion = ref.watch(sessionControllerProvider).value;
    final puedeDecidir =
        sesion?.membership.permissions.contains('time.approve') ?? false;
    final propio = sesion?.membership.id;

    return switch (jornadas) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.schedule_outlined,
          message: l10n.hoursEmpty,
        ),
      AsyncData(:final value) => ListView(
          padding: EdgeInsets.all(spacing.lg),
          children: [
            _Resumen(jornadas: value),
            SizedBox(height: spacing.lg),
            for (final dia in _agruparPorDia(value)) ...[
              SectionCard(
                label: dia.etiqueta(context),
                padded: false,
                child: Column(
                  children: [
                    for (final (i, fila) in dia.filas.indexed) ...[
                      if (i > 0)
                        Divider(height: 1, color: context.colors.outline),
                      _Jornada(
                        nombre: fila.name,
                        marcadaPor: fila.recordedByName,
                        jornada: fila.entry,
                        // Nadie decide sobre sus propias horas: el servidor lo
                        // rechaza igual, y ofrecer el botón sería mentir.
                        puedeDecidir:
                            puedeDecidir && fila.entry.membershipId != propio,
                        expandida: _expandida == fila.entry.id,
                        onTap: () => setState(
                          () => _expandida =
                              _expandida == fila.entry.id ? null : fila.entry.id,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: spacing.lg),
            ],
          ],
        ),
      AsyncError() => EmptyState(
          icon: Icons.error_outline,
          message: l10n.syncFailed,
        ),
      // La base local responde en un frame: un spinner acá solo parpadea, y
      // el mismo criterio ya vale en `project_screen.dart`.
      _ => const SizedBox.shrink(),
    };
  }
}

/// Lo que la obra lleva puesto. El número de jornadas sin aprobar va acá porque
/// es lo que convierte la pantalla en una bandeja y no en un dato de adorno.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.jornadas});

  final List<({String name, String recordedByName, TimeEntrySummary entry})>
      jornadas;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final total = jornadas.fold(
      Duration.zero,
      (suma, f) => suma + f.entry.worked,
    );
    final personas = jornadas.map((f) => f.entry.membershipId).toSet().length;
    final sinAprobar = jornadas.where((f) => f.entry.sinAprobar).length;

    return SectionCard(
      label: l10n.hoursHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hoursTotal(
              _duracion(l10n, total),
              l10n.hoursPeople(personas),
            ),
            style: context.texts.titleLarge,
          ),
          SizedBox(height: spacing.xs),
          Text(
            '${l10n.hoursShifts(jornadas.length)} · '
            '${l10n.hoursUnapproved(sinAprobar)}',
            style: context.texts.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Una jornada: colapsada dice quién, cuándo y cuánto; expandida, el detalle y
/// las acciones.
class _Jornada extends ConsumerStatefulWidget {
  const _Jornada({
    required this.nombre,
    required this.marcadaPor,
    required this.jornada,
    required this.puedeDecidir,
    required this.expandida,
    required this.onTap,
  });

  final String nombre;

  /// Quién registró la marca, cuando no fue la propia persona.
  final String marcadaPor;
  final TimeEntrySummary jornada;
  final bool puedeDecidir;
  final bool expandida;
  final VoidCallback onTap;

  @override
  ConsumerState<_Jornada> createState() => _JornadaState();
}

class _JornadaState extends ConsumerState<_Jornada> {
  bool _decidiendo = false;

  Future<void> _decidir({required bool aprobar}) async {
    if (_decidiendo) return;

    String? razon;
    if (!aprobar) {
      // Rechazar confirma y pide razón; aprobar no. El que necesita fricción es
      // el que le saca el día a alguien.
      razon = await pedirMotivoDeRechazo(context);
      if (razon == null) return;
    }

    setState(() => _decidiendo = true);
    try {
      await ref.read(timeEntryRepositoryProvider).decide(
            widget.jornada.id,
            approve: aprobar,
            reason: razon,
          );
    } finally {
      if (mounted) setState(() => _decidiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final material = MaterialLocalizations.of(context);
    final j = widget.jornada;

    String hora(DateTime d) =>
        material.formatTimeOfDay(TimeOfDay.fromDateTime(d.toLocal()));

    final rango = j.abierta
        ? l10n.hoursStillOpen
        : l10n.hoursRange(hora(j.clockInAt), hora(j.clockOutAt!));

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nombre.isEmpty
                            ? l10n.hoursUnknownPerson
                            : widget.nombre,
                        style: context.texts.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$rango · ${_duracion(l10n, j.worked)}',
                        style: context.texts.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.sm),
                _Estado(jornada: j),
                Icon(
                  widget.expandida ? Icons.expand_less : Icons.expand_more,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
            if (j.flags.isNotEmpty || j.enConflicto || j.lastRejection != null)
              Padding(
                padding: EdgeInsets.only(top: spacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (j.enConflicto)
                      StatusLine(
                        tone: StatusTone.danger,
                        label: l10n.hoursConflict,
                      ),
                    if (j.lastRejection != null)
                      StatusLine(
                        tone: StatusTone.warning,
                        label: _motivoDescarte(l10n, j.lastRejection!),
                      ),
                    for (final flag in j.flags)
                      StatusLine(
                        tone: StatusTone.warning,
                        label: flagLabel(l10n, flag),
                      ),
                  ],
                ),
              ),
            if (widget.expandida) ...[
              SizedBox(height: spacing.sm),
              if (j.method != 'SELF' && widget.marcadaPor.isNotEmpty)
                Text(
                  l10n.hoursRecordedBy(widget.marcadaPor),
                  style: context.texts.bodySmall,
                ),
              if (j.recordedOffline)
                Text(
                  l10n.hoursRecordedOffline,
                  style: context.texts.bodySmall,
                ),
              if (j.decisionReason != null && j.decisionReason!.isNotEmpty)
                Text(
                  l10n.hoursReason(j.decisionReason!),
                  style: context.texts.bodySmall,
                ),
              // Una jornada abierta no se decide: sin salida no hay nada que
              // aprobar, y el servidor la rechazaría con TIME_ENTRY_STILL_OPEN.
              if (widget.puedeDecidir && !j.abierta) ...[
                SizedBox(height: spacing.sm),
                // Los botones del tema son de ancho completo, así que van en
                // `Expanded`: sueltos en una fila reciben ancho infinito y el
                // layout revienta. Y de paso se tocan con guantes.
                Row(
                  children: [
                    if (!j.rechazada)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _decidiendo
                              ? null
                              : () => _decidir(aprobar: false),
                          child: _decidiendo
                              ? const _Esperando()
                              : Text(l10n.hoursReject),
                        ),
                      ),
                    if (!j.rechazada && !j.aprobada)
                      SizedBox(width: spacing.sm),
                    if (!j.aprobada)
                      Expanded(
                        child: FilledButton(
                          onPressed: _decidiendo
                              ? null
                              : () => _decidir(aprobar: true),
                          child: _decidiendo
                              ? const _Esperando()
                              : Text(l10n.hoursApprove),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// El estado de la jornada. `StatusLine` y no un chip: en una lista, un globo
/// de color por fila pesa más que el nombre y que el botón, y el estado es
/// lectura, no acción.
class _Estado extends StatelessWidget {
  const _Estado({required this.jornada});

  final TimeEntrySummary jornada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (tono, texto) = switch (jornada.status) {
      'APPROVED' => (StatusTone.success, l10n.hoursStatusApproved),
      'REJECTED' => (StatusTone.danger, l10n.hoursStatusRejected),
      _ => (StatusTone.warning, l10n.hoursStatusPending),
    };
    return StatusLine(tone: tono, label: texto);
  }
}

/// Que la decisión está en camino.
///
/// La escritura espera el turno de la bandeja, así que con red mala puede tardar
/// segundos de verdad — y un botón apagado sin nada más se lee como que la app
/// se colgó, no como que está trabajando.
class _Esperando extends StatelessWidget {
  const _Esperando();

  @override
  Widget build(BuildContext context) {
    final alto = context.spacing.lg;
    return SizedBox(
      height: alto,
      width: alto,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

/// El texto de un descarte del servidor. Llega como código y se traduce acá,
/// igual que las banderas (regla 24).
String _motivoDescarte(AppLocalizations l10n, String codigo) => switch (codigo) {
  'PAY_RATE_MISSING' => l10n.hoursDiscardedPayRate,
  'TIME_ENTRY_STILL_OPEN' => l10n.hoursDiscardedStillOpen,
  _ => codigo,
};

String _duracion(AppLocalizations l10n, Duration d) =>
    l10n.obrasDuration(d.inHours, d.inMinutes % 60);

/// Las jornadas de un mismo día, para que la lista se lea por fecha y no como
/// un rollo continuo.
typedef _Fila = ({String name, String recordedByName, TimeEntrySummary entry});

typedef _Dia = ({DateTime fecha, List<_Fila> filas});

extension on _Dia {
  String etiqueta(BuildContext context) =>
      MaterialLocalizations.of(context).formatMediumDate(fecha);
}

List<_Dia> _agruparPorDia(List<_Fila> jornadas) {
  final porDia = <DateTime, List<_Fila>>{};
  for (final fila in jornadas) {
    final local = fila.entry.clockInAt.toLocal();
    final dia = DateTime(local.year, local.month, local.day);
    porDia.putIfAbsent(dia, () => []).add(fila);
  }
  final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final d in dias) (fecha: d, filas: porDia[d]!)];
}

/// Las jornadas de una obra, de cualquier persona.
final jornadasDeLaObraProvider =
    StreamProvider.family<List<_Fila>, String>((ref, projectId) {
  return ref.watch(timeEntryRepositoryProvider).watchProjectEntries(projectId);
});
