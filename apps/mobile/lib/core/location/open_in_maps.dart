import 'package:url_launcher/url_launcher.dart';

/// Abre un lugar en la app de mapas del teléfono.
///
/// Se delega a propósito: construir navegación adentro es lo que la visión
/// descarta. Con punto va al lugar exacto; sin punto, a lo que el geocoder de
/// Google haga con la dirección escrita.
Future<void> openInMaps({double? lat, double? lng, String? address}) async {
  final consulta = (lat != null && lng != null)
      ? '$lat,$lng'
      : Uri.encodeComponent(address ?? '');
  if (consulta.isEmpty) return;
  await launchUrl(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$consulta'),
    mode: LaunchMode.externalApplication,
  );
}
