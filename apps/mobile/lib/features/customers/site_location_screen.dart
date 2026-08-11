import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/location/device_location.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/field_action_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/sync/connectivity.dart';
import '../../l10n/app_localizations.dart';

/// Radios que se ofrecen, en metros.
///
/// Es un rango con paso y no un campo de texto: nadie sabe cuánto es 150, y el
/// número solo significa algo mirando el círculo sobre el mapa.
const _radioMin = 50.0;
const _radioMax = 500.0;
const _radioPaso = 25;

/// Cuando la propiedad no tiene punto, el mapa abre acá.
///
/// Es el centro de Maryland, donde trabaja el design partner. Abrir en (0,0)
/// —en medio del Atlántico— haría que la primera acción sea siempre buscar el
/// continente.
const _centroPorDefecto = LatLng(39.0458, -76.6413);

/// Fija el punto y el radio de la geocerca de una propiedad.
///
/// Es pantalla completa y no una hoja: el punto se elige arrastrando con el
/// pulgar y necesita el ancho.
class SiteLocationScreen extends ConsumerStatefulWidget {
  const SiteLocationScreen({super.key, required this.site});

  final SiteSummary site;

  @override
  ConsumerState<SiteLocationScreen> createState() => _SiteLocationScreenState();
}

class _SiteLocationScreenState extends ConsumerState<SiteLocationScreen> {
  LatLng? _punto;
  double? _radio;
  bool _guardando = false;
  bool _buscandoUbicacion = false;
  LocationFailure? _falloUbicacion;

  /// `initialCameraPosition` solo se aplica al crear el mapa, así que mover el
  /// marcador no mueve la vista. Sin este controlador, "usar mi ubicación" pone
  /// el punto donde estás y te deja mirando el otro lado del continente.
  GoogleMapController? _mapa;

  @override
  void initState() {
    super.initState();
    if (widget.site.hasLocation) {
      _punto = LatLng(widget.site.lat!, widget.site.lng!);
    }
    _radio = widget.site.geofenceRadiusM?.toDouble();
  }

  @override
  void dispose() {
    _mapa?.dispose();
    super.dispose();
  }

  Future<void> _usarMiUbicacion() async {
    setState(() {
      _buscandoUbicacion = true;
      _falloUbicacion = null;
    });

    final resultado = await ref.read(deviceLocationProvider).current();
    if (!mounted) return;

    setState(() {
      _buscandoUbicacion = false;
      if (resultado.isOk) {
        _punto = LatLng(resultado.lat!, resultado.lng!);
      } else {
        _falloUbicacion = resultado.failure;
      }
    });

    if (resultado.isOk) {
      await _mapa?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(resultado.lat!, resultado.lng!), 17),
      );
    }
  }

  Future<void> _guardar() async {
    final punto = _punto;
    if (punto == null || _guardando) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .setSiteLocation(
            widget.site.id,
            lat: punto.latitude,
            lng: punto.longitude,
            geofenceRadiusM: _radio?.round(),
          );
    } finally {
      // La escritura es local y casi nunca falla, pero si falla el botón no
      // puede quedar deshabilitado para siempre.
      if (mounted) setState(() => _guardando = false);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hayRed = ref.watch(connectivityProvider).value ?? true;
    final radioDibujado = _radio ?? _radioMin * 2;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.siteLocationTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _punto ?? _centroPorDefecto,
                    zoom: _punto == null ? 9 : 17,
                  ),
                  onMapCreated: (controlador) => _mapa = controlador,
                  onTap: (posicion) => setState(() => _punto = posicion),
                  markers: {
                    if (_punto != null)
                      Marker(
                        markerId: const MarkerId('site'),
                        position: _punto!,
                        draggable: true,
                        onDragEnd: (posicion) =>
                            setState(() => _punto = posicion),
                      ),
                  },
                  circles: {
                    if (_punto != null)
                      Circle(
                        circleId: const CircleId('geofence'),
                        center: _punto!,
                        radius: radioDibujado,
                        fillColor: context.colors.primary.withValues(alpha: 0.12),
                        strokeColor: context.colors.primary,
                        strokeWidth: 2,
                      ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                if (!hayRed || _falloUbicacion != null)
                  Positioned(
                    left: context.spacing.lg,
                    right: context.spacing.lg,
                    top: context.spacing.lg,
                    child: _Aviso(
                      hayRed: hayRed,
                      fallo: _falloUbicacion,
                    ),
                  ),
              ],
            ),
          ),
          _Controles(
            direccion: widget.site.oneLine,
            punto: _punto,
            radio: _radio,
            guardando: _guardando,
            buscandoUbicacion: _buscandoUbicacion,
            onUsarMiUbicacion: _usarMiUbicacion,
            onRadio: (valor) => setState(() => _radio = valor),
            onGuardar: _guardar,
          ),
        ],
      ),
    );
  }
}

/// Lo que la pantalla dice cuando algo no está: sin red el mapa no dibuja, y sin
/// permiso no hay "usar mi ubicación". Ninguno de los dos impide poner el punto
/// a mano, y el texto lo dice.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.hayRed, required this.fallo});

  final bool hayRed;
  final LocationFailure? fallo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mensaje = switch (fallo) {
      LocationFailure.serviceDisabled => l10n.siteLocationServiceDisabled,
      LocationFailure.denied => l10n.siteLocationDenied,
      LocationFailure.deniedForever => l10n.siteLocationDeniedForever,
      LocationFailure.timeout => l10n.siteLocationTimeout,
      null => l10n.siteLocationNoNetwork,
    };

    return StatusChip(
      tone: StatusTone.warning,
      label: mensaje,
      expand: true,
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.direccion,
    required this.punto,
    required this.radio,
    required this.guardando,
    required this.buscandoUbicacion,
    required this.onUsarMiUbicacion,
    required this.onRadio,
    required this.onGuardar,
  });

  final String direccion;
  final LatLng? punto;
  final double? radio;
  final bool guardando;
  final bool buscandoUbicacion;
  final VoidCallback onUsarMiUbicacion;
  final ValueChanged<double> onRadio;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // La dirección y las coordenadas en texto, siempre: sin tiles son
            // lo único que ubica, y es lo que se dicta por teléfono.
            Text(direccion, style: context.texts.labelLarge),
            if (punto != null) ...[
              SizedBox(height: context.spacing.xs),
              Text(
                l10n.siteLocationCoords(
                  punto!.latitude.toStringAsFixed(5),
                  punto!.longitude.toStringAsFixed(5),
                ),
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: context.spacing.sm),
            Text(
              l10n.siteLocationHint,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.spacing.md),
            OutlinedButton.icon(
              onPressed: buscandoUbicacion ? null : onUsarMiUbicacion,
              icon: buscandoUbicacion
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(l10n.siteLocationUseMine),
            ),
            SizedBox(height: context.spacing.md),
            Row(
              children: [
                Text(l10n.siteLocationRadius, style: context.texts.labelLarge),
                const Spacer(),
                Text(
                  radio == null
                      ? l10n.siteLocationRadiusDefault
                      : l10n.siteLocationRadiusValue(radio!.round()),
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Slider(
              value: (radio ?? _radioMin * 2).clamp(_radioMin, _radioMax),
              min: _radioMin,
              max: _radioMax,
              divisions: ((_radioMax - _radioMin) / _radioPaso).round(),
              onChanged: onRadio,
            ),
            SizedBox(height: context.spacing.sm),
            FieldActionButton(
              onPressed: punto == null || guardando ? null : onGuardar,
              label: l10n.siteLocationSave,
              icon: Icons.place_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
