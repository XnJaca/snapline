import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/device_location.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/field_action_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'week_screen.dart';

/// La pantalla que la visión le promete al trabajador: dónde trabajo hoy,
/// marcar entrada, marcar salida.
///
/// **Marcar nunca falla** (regla 9): el GPS tiene un tope y su ausencia es una
/// bandera, no un bloqueo. La jornada no espera al satélite.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  String? _obraElegida;
  bool _marcando = false;
  bool _sinUbicacionAviso = false;

  Future<void> _marcar({TimeEntrySummary? abierta}) async {
    final sesion = ref.read(sessionControllerProvider).value;
    if (sesion == null || _marcando) return;
    setState(() {
      _marcando = true;
      _sinUbicacionAviso = false;
    });

    // La escalera de evidencia: se intenta el GPS con su tope. Lo que no haya
    // no detiene nada — la ausencia viaja como ausencia y el servidor pone la
    // bandera. (La foto de respaldo entra con la tanda de cámara.)
    final ubicacion = await ref.read(deviceLocationProvider).current();
    final evidencia = ClockEvidence(
      lat: ubicacion.lat,
      lng: ubicacion.lng,
      isMockLocation: false,
    );

    final repo = ref.read(timeEntryRepositoryProvider);
    if (abierta != null) {
      await repo.clockOut(abierta.id, evidence: evidencia);
    } else {
      final obras = await repo.watchTodayProjects(sesion.membership.id).first;
      final obra = _obraElegida ?? (obras.length == 1 ? obras.first.id : null);
      if (obra == null) {
        // Sin obra elegible no hay marcaje que hacer; la pantalla ya lo explica.
        if (mounted) setState(() => _marcando = false);
        return;
      }
      await repo.clockIn(
        projectId: obra,
        membershipId: sesion.membership.id,
        recordedByMembershipId: sesion.membership.id,
        companyId: sesion.membership.companyId,
        evidence: evidencia,
      );
    }

    if (!mounted) return;
    setState(() {
      _marcando = false;
      _sinUbicacionAviso = !ubicacion.isOk;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final membershipId = sesion.membership.id;
    final obras =
        ref.watch(todayProjectsProvider(membershipId)).value ??
        const <TodayProject>[];
    final abierta = ref.watch(openEntryProvider(membershipId)).value;

    return AppScaffold(
      title: l10n.todayTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WeekScreen()),
          ),
          child: Text(l10n.todayWeekLink),
        ),
      ],
      body: obras.isEmpty && abierta == null
          ? _Vacio(message: l10n.todayNoAssignments)
          : _Jornada(
              obras: obras,
              abierta: abierta,
              obraElegida: _obraElegida,
              marcando: _marcando,
              sinUbicacionAviso: _sinUbicacionAviso,
              onElegirObra: (id) => setState(() => _obraElegida = id),
              onMarcar: () => _marcar(abierta: abierta),
            ),
    );
  }
}

class _Jornada extends StatelessWidget {
  const _Jornada({
    required this.obras,
    required this.abierta,
    required this.obraElegida,
    required this.marcando,
    required this.sinUbicacionAviso,
    required this.onElegirObra,
    required this.onMarcar,
  });

  final List<TodayProject> obras;
  final TimeEntrySummary? abierta;
  final String? obraElegida;
  final bool marcando;
  final bool sinUbicacionAviso;
  final ValueChanged<String> onElegirObra;
  final VoidCallback onMarcar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jornada = abierta;

    return ListView(
      padding: EdgeInsets.all(context.spacing.lg),
      children: [
        if (jornada != null && jornada.enConflicto) ...[
          _Conflicto(),
          SizedBox(height: context.spacing.lg),
        ],
        if (jornada != null) ...[
          _Cronometro(desde: jornada.clockInAt),
          SizedBox(height: context.spacing.sm),
          Center(
            child: Text(
              l10n.todayOpenSince(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay.fromDateTime(jornada.clockInAt.toLocal()),
                ),
              ),
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ] else ...[
          // La obra: una sola no pregunta, varias se eligen.
          for (final obra in obras) ...[
            _ObraCard(
              obra: obra,
              seleccionada:
                  obras.length == 1 || obra.id == obraElegida,
              onTap: () => onElegirObra(obra.id),
            ),
            SizedBox(height: context.spacing.sm),
          ],
        ],
        if (sinUbicacionAviso) ...[
          SizedBox(height: context.spacing.sm),
          StatusChip(
            tone: StatusTone.warning,
            label: l10n.todayNoLocationWarning,
            expand: true,
          ),
        ],
        SizedBox(height: context.spacing.xl),
        FieldActionButton(
          onPressed: marcando ||
                  (jornada == null &&
                      obras.length > 1 &&
                      obraElegida == null)
              ? null
              : onMarcar,
          label: marcando
              ? l10n.todayGettingLocation
              : (jornada == null ? l10n.todayClockIn : l10n.todayClockOut),
          icon: jornada == null ? Icons.login : Icons.logout,
        ),
      ],
    );
  }
}

/// El conflicto se explica, no se resuelve: la regla 12 lo deja en manos de un
/// humano de la oficina, y un estado sin explicación se lee como un error de la
/// app.
class _Conflicto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: BorderRadius.circular(context.spacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_problem_outlined, color: context.colors.onErrorContainer),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.todayConflictTitle,
                  style: context.texts.titleSmall?.copyWith(
                    color: context.colors.onErrorContainer,
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                Text(
                  l10n.todayConflictBody,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final transcurrido = DateTime.now().difference(widget.desde);
    final horas = transcurrido.inHours.toString().padLeft(2, '0');
    final minutos = (transcurrido.inMinutes % 60).toString().padLeft(2, '0');
    final segundos = (transcurrido.inSeconds % 60).toString().padLeft(2, '0');

    return Center(
      // displaySmall ya trae tabularFigures: las cifras no bailan al correr.
      child: Text('$horas:$minutos:$segundos', style: context.texts.displaySmall),
    );
  }
}

class _ObraCard extends StatelessWidget {
  const _ObraCard({
    required this.obra,
    required this.seleccionada,
    required this.onTap,
  });

  final TodayProject obra;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionada
          ? context.colors.primaryContainer
          : context.colors.surfaceContainerHighest,
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
                color: seleccionada
                    ? context.colors.onPrimaryContainer
                    : context.colors.onSurfaceVariant,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Text(
                  obra.name,
                  style: context.texts.titleMedium?.copyWith(
                    color: seleccionada
                        ? context.colors.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
              if (seleccionada)
                Icon(
                  Icons.check_circle_outline,
                  color: context.colors.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: context.colors.onSurfaceVariant,
            ),
            SizedBox(height: context.spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
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
