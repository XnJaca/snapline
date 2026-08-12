import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/open_in_maps.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/labeled_value.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import 'obras_screen.dart';
import 'registro_tab.dart';

/// La obra del trabajador, con tabs — el mismo patrón que el detalle del
/// OWNER, con el contenido del campo: acá se marca y se mira el registro.
class ObraScreen extends ConsumerWidget {
  const ObraScreen({super.key, required this.obra});

  final TodayProject obra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(obra.name),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.obraTabRegistro),
              Tab(text: l10n.obraTabDetalle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RegistroTab(obra: obra),
            _DetalleTab(obra: obra),
          ],
        ),
      ),
    );
  }
}

/// El lugar: la dirección y cómo llegar. El cliente no — la cuadrilla no
/// navega cartera.
class _DetalleTab extends ConsumerWidget {
  const _DetalleTab({required this.obra});

  final TodayProject obra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Del stream, no del argumento: si la dirección cambia por el pull, la
    // pantalla se entera.
    final lugar = ref.watch(placeProvider(obra.id)).value ?? obra;

    return ListView(
      padding: EdgeInsets.all(context.spacing.lg),
      children: [
        if (lugar.address.isNotEmpty)
          LabeledValue(label: l10n.detalleDireccion, value: lugar.address),
        if (lugar.address.isNotEmpty || lugar.hasLocation) ...[
          SizedBox(height: context.spacing.lg),
          OutlinedButton.icon(
            onPressed: () => openInMaps(
              lat: lugar.lat,
              lng: lugar.lng,
              address: lugar.address,
            ),
            icon: const Icon(Icons.directions_outlined),
            label: Text(l10n.todayOpenInMaps),
          ),
        ],
      ],
    );
  }
}
