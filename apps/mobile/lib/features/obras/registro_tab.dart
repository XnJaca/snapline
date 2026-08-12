import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/field_action_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import '../today/evidence_collector.dart';
import '../today/flag_labels.dart';
import 'obras_screen.dart';

/// La acción y la historia en un solo lugar: marcar acá, y abajo las jornadas
/// de esta obra, colapsadas con su total y expandibles al detalle.
///
/// **Marcar nunca falla** (regla 9): la lógica es la de SPEC-0008, intacta —
/// este tab solo le da un hogar.
class RegistroTab extends ConsumerStatefulWidget {
  const RegistroTab({super.key, required this.obra});

  final TodayProject obra;

  @override
  ConsumerState<RegistroTab> createState() => _RegistroTabState();
}

class _RegistroTabState extends ConsumerState<RegistroTab> {
  bool _marcando = false;
  bool _sinUbicacionAviso = false;

  Future<void> _marcar(TimeEntrySummary? abierta) async {
    final sesion = ref.read(sessionControllerProvider).value;
    if (sesion == null || _marcando) return;
    setState(() {
      _marcando = true;
      _sinUbicacionAviso = false;
    });

    var conUbicacion = false;
    var marco = false;
    try {
      final capturada = await ref
          .read(evidenceCollectorProvider)
          .collect(projectId: widget.obra.id);
      conUbicacion = capturada.conUbicacion || capturada.conFoto;

      final repo = ref.read(timeEntryRepositoryProvider);
      if (abierta != null) {
        await repo.clockOut(abierta.id, evidence: capturada.evidence);
      } else {
        await repo.clockIn(
          projectId: widget.obra.id,
          membershipId: sesion.membership.id,
          recordedByMembershipId: sesion.membership.id,
          companyId: sesion.membership.companyId,
          evidence: capturada.evidence,
        );
      }
      marco = true;
    } finally {
      if (mounted) {
        setState(() {
          _marcando = false;
          // Solo si de verdad se escribió: confirmar en falso sería peor que
          // no avisar.
          _sinUbicacionAviso = marco && !conUbicacion;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final membershipId = sesion.membership.id;
    final abierta = ref.watch(openEntryProvider(membershipId)).value;
    // La abierta ya está arriba como cronómetro: repetirla en la lista de
    // pasadas se leería como una jornada duplicada.
    final jornadas =
        (ref.watch(registroProvider((membershipId, widget.obra.id))).value ??
                const <TimeEntrySummary>[])
            .where((j) => j.id != abierta?.id)
            .toList(growable: false);

    // La jornada abierta puede ser de OTRA obra: acá no se puede ni marcar
    // entrada (ya hay una) ni salida (es de otro lugar).
    final abiertaAca = abierta?.projectId == widget.obra.id ? abierta : null;
    final abiertaEnOtra = abierta != null && abiertaAca == null;

    return ListView(
      padding: EdgeInsets.all(context.spacing.lg),
      children: [
        if (abiertaAca != null && abiertaAca.enConflicto) ...[
          StatusChip(
            tone: StatusTone.danger,
            label: l10n.todayConflictBody,
            expand: true,
          ),
          SizedBox(height: context.spacing.lg),
        ],
        if (abiertaAca != null) ...[
          _Cronometro(desde: abiertaAca.clockInAt),
        ] else if (abiertaEnOtra) ...[
          Builder(builder: (context) {
            // Mientras el stream no emitió el nombre, el texto sin obra: un
            // `…` literal sería una cadena quemada (regla 24).
            final otra =
                ref.watch(placeProvider(abierta.projectId)).value?.name;
            return StatusChip(
              tone: StatusTone.info,
              label: otra == null
                  ? l10n.registroAbiertaEnOtraSinNombre
                  : l10n.registroAbiertaEnOtra(otra),
              expand: true,
            );
          }),
        ],
        if (_sinUbicacionAviso) ...[
          SizedBox(height: context.spacing.sm),
          StatusChip(
            tone: StatusTone.warning,
            label: l10n.todayNoLocationWarning,
            expand: true,
          ),
        ],
        if (!abiertaEnOtra) ...[
          SizedBox(height: context.spacing.xl),
          FieldActionButton(
            onPressed: _marcando ? null : () => _marcar(abiertaAca),
            label: _marcando
                ? l10n.todayGettingLocation
                : (abiertaAca == null ? l10n.todayClockIn : l10n.todayClockOut),
            icon: abiertaAca == null ? Icons.login : Icons.logout,
          ),
        ],
        SizedBox(height: context.spacing.xl),
        if (jornadas.isNotEmpty) ...[
          Text(l10n.registroPastTitle, style: context.texts.titleSmall),
          SizedBox(height: context.spacing.sm),
          for (final jornada in jornadas) _JornadaTile(jornada: jornada),
        ],
      ],
    );
  }
}

class _Cronometro extends StatefulWidget {
  const _Cronometro({required this.desde});

  final DateTime desde;

  @override
  State<_Cronometro> createState() => _CronometroState();
}

class _CronometroState extends State<_Cronometro> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _animo(AppLocalizations l10n, Duration transcurrido) {
    if (transcurrido.inHours >= 14) return l10n.todayCheerTooLong;
    if (transcurrido.inHours >= 8) return l10n.todayCheerLate;
    if (transcurrido.inHours >= 4) return l10n.todayCheerMid;
    if (transcurrido.inHours >= 1) return l10n.todayCheerEarly;
    return l10n.todayCheerStart;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transcurrido = DateTime.now().difference(widget.desde);
    final horas = transcurrido.inHours.toString().padLeft(2, '0');
    final minutos = (transcurrido.inMinutes % 60).toString().padLeft(2, '0');
    final segundos = (transcurrido.inSeconds % 60).toString().padLeft(2, '0');
    final avisa = transcurrido.inHours >= 14;

    return Column(
      children: [
        Center(
          // displaySmall trae tabularFigures: las cifras no bailan al correr.
          child: Text(
            '$horas:$minutos:$segundos',
            style: context.texts.displaySmall,
          ),
        ),
        SizedBox(height: context.spacing.sm),
        Center(
          child: Text(
            l10n.todayOpenSince(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay.fromDateTime(widget.desde.toLocal()),
              ),
            ),
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: context.spacing.sm),
        if (avisa)
          StatusChip(
            tone: StatusTone.warning,
            label: _animo(l10n, transcurrido),
            expand: true,
          )
        else
          Center(
            child: Text(
              _animo(l10n, transcurrido),
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Una jornada pasada: colapsada dice fecha y total; expandida, el detalle.
class _JornadaTile extends StatelessWidget {
  const _JornadaTile({required this.jornada});

  final TimeEntrySummary jornada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);

    final fin = jornada.clockOutAt ?? DateTime.now();
    final total =
        fin.difference(jornada.clockInAt) -
        Duration(minutes: jornada.breakMinutes);
    final totalTexto =
        l10n.obrasDuration(total.inHours, total.inMinutes % 60);

    String hora(DateTime d) =>
        material.formatTimeOfDay(TimeOfDay.fromDateTime(d.toLocal()));

    return ExpansionTile(
      tilePadding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      title: Text(
        material.formatMediumDate(jornada.clockInAt.toLocal()),
        style: context.texts.titleSmall,
      ),
      trailing: Text(
        totalTexto,
        style: context.texts.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.sm,
            vertical: context.spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.registroEntrada(hora(jornada.clockInAt))),
              SizedBox(height: context.spacing.xs),
              Text(
                jornada.clockOutAt == null
                    ? l10n.registroSinSalida
                    : l10n.registroSalida(hora(jornada.clockOutAt!)),
              ),
              SizedBox(height: context.spacing.xs),
              Text(l10n.registroTotal(totalTexto)),
              SizedBox(height: context.spacing.sm),
              Wrap(
                spacing: context.spacing.xs,
                runSpacing: context.spacing.xs,
                children: [
                  switch (jornada.status) {
                    'APPROVED' => StatusChip(
                        tone: StatusTone.success, label: l10n.weekApproved),
                    'REJECTED' => StatusChip(
                        tone: StatusTone.danger, label: l10n.weekRejected),
                    _ => StatusChip(
                        tone: StatusTone.info, label: l10n.weekPendingApproval),
                  },
                  if (jornada.enConflicto)
                    StatusChip(
                      tone: StatusTone.danger,
                      label: l10n.todayConflictTitle,
                    )
                  else if (jornada.pendiente)
                    StatusChip(
                      tone: StatusTone.info,
                      label: l10n.weekSavedOnPhone,
                    ),
                  for (final bandera in jornada.flags)
                    StatusChip(
                      tone: StatusTone.warning,
                      label: flagLabel(l10n, bandera),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final registroProvider = StreamProvider.family<List<TimeEntrySummary>,
    (String, String)>((ref, claves) {
  final (membershipId, projectId) = claves;
  return ref.watch(timeEntryRepositoryProvider).watchForProject(
        membershipId,
        projectId,
        DateTime.now().subtract(const Duration(days: 7)),
      );
});
