import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/location/open_in_maps.dart';
import '../../core/theme/theme_extensions.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/app_localizations.dart';
import 'site_location_screen.dart';

/// El bloque de ubicación dentro de la ficha de una propiedad.
///
/// Sin punto invita a fijarlo; con punto muestra las coordenadas y deja
/// corregirlo. **No dibuja un mapa acá**: la propiedad se ubica en la pantalla
/// completa, y un mapa de 200px que además tiene que cargar tiles sería un
/// costo por cada vez que alguien abre la ficha a corregir un teléfono.
class SiteLocationBlock extends ConsumerWidget {
  const SiteLocationBlock({super.key, required this.site});

  final SiteSummary site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // La ficha recibe el site del stream de Drift, así que al volver de la
    // pantalla del mapa el punto nuevo llega solo.
    final actual =
        ref
            .watch(customerSitesProvider(site.customerId))
            .value
            ?.where((s) => s.id == site.id)
            .firstOrNull ??
        site;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.siteLocationSection, style: context.texts.labelLarge),
        SizedBox(height: context.spacing.sm),
        if (!actual.hasLocation)
          Text(
            l10n.siteLocationEmpty,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: context.spacing.xl,
                color: context.colors.onSurfaceVariant,
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  l10n.siteLocationCoords(
                    actual.lat!.toStringAsFixed(5),
                    actual.lng!.toStringAsFixed(5),
                  ),
                  style: context.texts.bodyMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    openInMaps(lat: actual.lat, lng: actual.lng),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.siteLocationOpenInMaps),
              ),
            ],
          ),
        SizedBox(height: context.spacing.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (_) => SiteLocationScreen(site: actual),
            ),
          ),
          icon: const Icon(Icons.map_outlined),
          label: Text(
            actual.hasLocation ? l10n.siteLocationEdit : l10n.siteLocationSet,
          ),
        ),
      ],
    );
  }
}
