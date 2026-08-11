import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Por qué no se pudo leer la ubicación. La pantalla necesita distinguirlos: cada
/// uno se resuelve distinto y decirle "error" a los cuatro no ayuda a nadie.
enum LocationFailure {
  /// El GPS del teléfono está apagado.
  serviceDisabled,

  /// La persona dijo que no, pero se puede volver a preguntar.
  denied,

  /// Dijo que no para siempre: solo se arregla en los ajustes del sistema.
  deniedForever,

  /// Tardó más que el tope. Pasa bajo techo y en sótanos.
  timeout,
}

class LocationResult {
  const LocationResult.ok(this.lat, this.lng) : failure = null;
  const LocationResult.failed(this.failure) : lat = null, lng = null;

  final double? lat;
  final double? lng;
  final LocationFailure? failure;

  bool get isOk => failure == null;
}

/// Lee la posición del dispositivo **una sola vez**.
///
/// No expone stream ni suscripción a propósito: la visión descarta el tracking
/// continuo, y con `whileInUse` alcanza. Ver SPEC-0007.
abstract class DeviceLocation {
  Future<LocationResult> current();
}

class GeolocatorDeviceLocation implements DeviceLocation {
  const GeolocatorDeviceLocation();

  /// Pasado este tope se devuelve `timeout` y la pantalla sigue.
  ///
  /// Corto y nadie tiene coordenadas; largo y parece que la app se colgó. El
  /// número se ajusta en obra, no en una reunión.
  static const espera = Duration(seconds: 10);

  @override
  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failed(LocationFailure.serviceDisabled);
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.deniedForever) {
      return const LocationResult.failed(LocationFailure.deniedForever);
    }
    if (permiso == LocationPermission.denied) {
      return const LocationResult.failed(LocationFailure.denied);
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: espera,
        ),
      );
      return LocationResult.ok(posicion.latitude, posicion.longitude);
    } on Object {
      // `timeLimit` vencido llega como TimeoutException, pero un GPS que falla
      // tira otras. Todas significan lo mismo acá: no hubo punto a tiempo.
      return const LocationResult.failed(LocationFailure.timeout);
    }
  }
}

final deviceLocationProvider = Provider<DeviceLocation>(
  (ref) => const GeolocatorDeviceLocation(),
);
