import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import '../today/evidence_collector.dart';
import '../obras/obras_screen.dart';

/// El tab Personas: la gente de la obra de hoy — quién está adentro, quién
/// salió, quién no marcó — y marcar por quien haga falta.
///
/// La lista es **de la obra y no de la cuadrilla**: quien fue ese día ficha por
/// quien también fue. Y se puede marcar por alguien fuera de la lista — la
/// bandera del servidor lo señala para quien aprueba, nunca lo bloquea. Una
/// pantalla que solo dejara elegir de la lista convertiría la bandera en
/// bloqueo por la puerta de atrás.
class PersonasTab extends ConsumerStatefulWidget {
  const PersonasTab({super.key, this.projectId});

  /// Con obra fija —el tab Cuadrilla dentro de una obra— la lista es de ESA
  /// obra, sin selector. Sin ella, la del eje: la primera de hoy, con chips
  /// para cambiar.
  final String? projectId;

  @override
  ConsumerState<PersonasTab> createState() => _PersonasTabState();
}

class _PersonasTabState extends ConsumerState<PersonasTab> {
  String? _obraElegida;
  String? _marcando;

  Future<void> _marcarPor(CrewmateToday persona, String projectId) async {
    final sesion = ref.read(sessionControllerProvider).value;
    if (sesion == null || _marcando != null) return;
    setState(() => _marcando = persona.membershipId);

    try {
      // La misma escalera que el marcaje propio: GPS con tope, y sin GPS la
      // foto del frente de obra — desde el teléfono del foreman.
      final capturada = await ref
          .read(evidenceCollectorProvider)
          .collect(projectId: projectId);
      final evidencia = capturada.evidence;

      final repo = ref.read(timeEntryRepositoryProvider);
      if (persona.adentro) {
        await repo.clockOut(persona.openEntryId!, evidence: evidencia);
      } else {
        await repo.clockIn(
          projectId: projectId,
          membershipId: persona.membershipId,
          recordedByMembershipId: sesion.membership.id,
          recordedByRole: sesion.membership.role.json ?? 'WORKER',
          companyId: sesion.membership.companyId,
          evidence: evidencia,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).crewMarkedBy)),
      );
    } finally {
      if (mounted) setState(() => _marcando = null);
    }
  }

  Future<void> _marcarPorOtra(String projectId) async {
    // El sheet abre ya y lee adentro: un prefetch bloquearía el toque en lo
    // que un stream tarde en emitir.
    final elegida = await showModalBottomSheet<CrewmateToday>(
      context: context,
      useSafeArea: true,
      builder: (context) => _OtraPersonaSheet(projectId: projectId),
    );

    if (elegida != null && mounted) await _marcarPor(elegida, projectId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    if (sesion == null) return const SizedBox.shrink();

    final obras = widget.projectId != null
        ? const <TodayProject>[]
        : ref.watch(todayProjectsProvider(sesion.membership.id)).value ??
            const <TodayProject>[];
    final obraId =
        widget.projectId ??
        (obras.any((o) => o.id == _obraElegida) ? _obraElegida : null) ??
        (obras.isNotEmpty ? obras.first.id : null);

    return obraId == null
        ? EmptyState(
            icon: Icons.groups_outlined,
            message: l10n.crewNoProject,
          )
        : _Gente(
            obras: obras,
            obraId: obraId,
            marcando: _marcando,
            onElegirObra: (id) => setState(() => _obraElegida = id),
            onMarcar: (p) => _marcarPor(p, obraId),
            onOtraPersona: () => _marcarPorOtra(obraId),
          );
  }
}

class _Gente extends ConsumerWidget {
  const _Gente({
    required this.obras,
    required this.obraId,
    required this.marcando,
    required this.onElegirObra,
    required this.onMarcar,
    required this.onOtraPersona,
  });

  final List<TodayProject> obras;
  final String obraId;
  final String? marcando;
  final ValueChanged<String> onElegirObra;
  final ValueChanged<CrewmateToday> onMarcar;
  final VoidCallback onOtraPersona;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gente =
        ref.watch(crewTodayProvider(obraId)).value ?? const <CrewmateToday>[];

    return ListView(
      padding: EdgeInsets.all(context.spacing.lg),
      children: [
        // Varias obras hoy: se cambia tocando, como en Hoy.
        if (obras.length > 1) ...[
          Wrap(
            spacing: context.spacing.sm,
            children: [
              for (final obra in obras)
                ChoiceChip(
                  label: Text(obra.name),
                  selected: obra.id == obraId,
                  onSelected: (_) => onElegirObra(obra.id),
                ),
            ],
          ),
          SizedBox(height: context.spacing.lg),
        ],
        SectionCard(
          label: l10n.crewTodayHeader,
          padded: false,
          child: Column(
            children: [
              for (final (i, persona) in gente.indexed) ...[
                if (i > 0) Divider(height: 1, color: context.colors.outline),
                _PersonaRow(
                  persona: persona,
                  ocupada: marcando == persona.membershipId,
                  // Un marcaje a la vez: los demás botones se apagan de
                  // verdad, no solo el de la persona en curso — un botón que
                  // parece vivo y no hace nada es peor que uno gris.
                  onMarcar: marcando != null ? null : () => onMarcar(persona),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: context.spacing.lg),
        OutlinedButton.icon(
          onPressed: marcando != null ? null : onOtraPersona,
          icon: const Icon(Icons.person_add_alt_outlined),
          label: Text(l10n.crewSomeoneElse),
        ),
      ],
    );
  }
}

/// La persona con su estado del día — explícito: **hoy**, en esta obra — y la
/// acción con palabras, no un icono que hay que adivinar.
///
/// Adentro solo se ofrece marcar salida: la segunda entrada no existe como
/// opción, ni acá ni en el servidor (un registro abierto por persona).
class _PersonaRow extends StatelessWidget {
  const _PersonaRow({
    required this.persona,
    required this.ocupada,
    required this.onMarcar,
  });

  final CrewmateToday persona;
  final bool ocupada;
  final VoidCallback? onMarcar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);

    final estado = persona.adentro
        ? StatusLine(
            tone: StatusTone.success,
            label: l10n.crewInSince(
              material.formatTimeOfDay(
                TimeOfDay.fromDateTime(persona.lastClockIn!.toLocal()),
              ),
            ),
          )
        : persona.marcoHoy
            ? StatusLine(
                tone: StatusTone.info,
                label: l10n.crewOutAt(
                  material.formatTimeOfDay(
                    TimeOfDay.fromDateTime(persona.lastClockOut!.toLocal()),
                  ),
                ),
              )
            : StatusLine(tone: StatusTone.warning, label: l10n.crewNotClockedIn);

    // Quién y cómo está a la izquierda; la acción a la derecha. Un botón de
    // ancho completo debajo del estado ponía a los dos a pelear por el mismo
    // peso, y el estado es lectura, no acción.
    return Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(persona.name, style: context.texts.titleMedium),
                SizedBox(height: context.spacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: estado,
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.md),
          OutlinedButton(
            onPressed: onMarcar,
            child: ocupada
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(persona.adentro ? l10n.crewMarkOut : l10n.crewMarkIn),
          ),
        ],
      ),
    );
  }
}

/// La gente conocida que no aparece asignada a la obra: la salida de escape.
class _OtraPersonaSheet extends ConsumerWidget {
  const _OtraPersonaSheet({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final todos =
        ref.watch(everyoneProvider).value ?? const <CrewmateToday>[];
    final enObra = {
      for (final p
          in ref.watch(crewTodayProvider(projectId)).value ??
              const <CrewmateToday>[])
        p.membershipId,
    };
    final fuera = todos
        .where((p) => !enObra.contains(p.membershipId))
        .toList(growable: false);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.all(context.spacing.lg),
        children: [
          Text(
            l10n.crewSomeoneElseHelp,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacing.md),
          for (final p in fuera)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(p.name),
              onTap: () => Navigator.of(context).pop(p),
            ),
        ],
      ),
    );
  }
}

final everyoneProvider = StreamProvider<List<CrewmateToday>>((ref) {
  return ref.watch(timeEntryRepositoryProvider).watchEveryone();
});

final crewTodayProvider =
    StreamProvider.family<List<CrewmateToday>, String>((ref, projectId) {
  return ref.watch(timeEntryRepositoryProvider).watchCrewToday(projectId);
});
