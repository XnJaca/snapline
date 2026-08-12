import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/project_status.dart';
import '../../core/location/open_in_maps.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/labeled_value.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import '../crew/personas_tab.dart';
import '../projects/project_status_display.dart';
import 'obras_screen.dart';
import 'registro_tab.dart';

/// La obra del trabajador, con tabs — el mismo patrón que el detalle del
/// OWNER, con el contenido del campo: acá se marca y se mira el registro.
///
/// Quien puede ver a la cuadrilla (`crews.read`) tiene además el tab
/// Cuadrilla: la gente de ESTA obra, marcar por otro incluido. El permiso lo
/// dice el servidor; el móvil no replica la tabla de roles.
class ObraScreen extends ConsumerWidget {
  const ObraScreen({super.key, required this.obra});

  final TodayProject obra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sesion = ref.watch(sessionControllerProvider).value;
    final conCuadrilla =
        sesion?.membership.permissions.contains('crews.read') ?? false;

    return DefaultTabController(
      length: conCuadrilla ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(obra.name),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.obraTabRegistro),
              if (conCuadrilla) Tab(text: l10n.obraTabCuadrilla),
              Tab(text: l10n.obraTabDetalle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RegistroTab(obra: obra),
            if (conCuadrilla) PersonasTab(projectId: obra.id),
            _DetalleTab(obra: obra),
          ],
        ),
      ),
    );
  }
}

/// El lugar y su ficha: estado, fechas, tipo de trabajo y descripción — lo
/// que ya baja al teléfono. El cliente no: la cuadrilla no navega cartera.
/// Fases tampoco, todavía: no existen en el dominio.
class _DetalleTab extends ConsumerWidget {
  const _DetalleTab({required this.obra});

  final TodayProject obra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    // Del stream, no del argumento: si la dirección cambia por el pull, la
    // pantalla se entera.
    final lugar = ref.watch(placeProvider(obra.id)).value ?? obra;
    final ficha = ref.watch(obraDetalleProvider(obra.id)).value;

    final estado = ficha == null
        ? null
        : ProjectStatus.values.firstWhere(
            (s) => s.json == ficha.status,
            orElse: () => ProjectStatus.$unknown,
          );

    String? fecha(DateTime? d) =>
        d == null ? null : material.formatMediumDate(d.toLocal());

    // Dos secciones con nombre, cada una en su card: el lugar y la ficha.
    // Nada suelto sobre el fondo.
    return ListView(
      padding: EdgeInsets.all(context.spacing.lg),
      children: [
        if (lugar.address.isNotEmpty || lugar.hasLocation) ...[
          SectionCard(
            label: l10n.detalleSeccionLugar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lugar.address.isNotEmpty)
                  LabeledValue(
                    label: l10n.detalleDireccion,
                    value: lugar.address,
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => openInMaps(
                      lat: lugar.lat,
                      lng: lugar.lng,
                      address: lugar.address,
                    ),
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(l10n.todayOpenInMaps),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.lg),
        ],
        if (ficha != null) ...[
          SectionCard(
            label: l10n.detalleSeccionFicha,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El estado es un campo más de la ficha, con el mismo peso que
                // los demás: como chip se llevaba todo el protagonismo.
                if (estado != null && estado != ProjectStatus.$unknown) ...[
                  Text(
                    l10n.detalleEstado,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  StatusLine(tone: estado.tone, label: estado.label(l10n)),
                  SizedBox(height: context.spacing.md),
                ],
                LabeledValue(
                  label: l10n.detalleServicio,
                  value: ficha.serviceType,
                ),
                LabeledValue(
                  label: l10n.detalleInicio,
                  value: fecha(ficha.startDate),
                ),
                LabeledValue(
                  label: l10n.detalleObjetivo,
                  value: fecha(ficha.targetEndDate),
                ),
                LabeledValue(
                  label: l10n.detalleTerminada,
                  value: fecha(ficha.actualEndDate),
                ),
                LabeledValue(
                  label: l10n.detalleDescripcion,
                  value: ficha.description,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

final obraDetalleProvider =
    StreamProvider.family<ObraDetalle?, String>((ref, projectId) {
  return ref.watch(timeEntryRepositoryProvider).watchObraDetalle(projectId);
});
