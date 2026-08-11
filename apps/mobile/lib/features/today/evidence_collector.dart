import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/device_location.dart';
import '../../core/media/photo_capture.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

/// Lo que la escalera consiguió, y qué escalón tocó.
class CollectedEvidence {
  const CollectedEvidence({
    required this.evidence,
    required this.conUbicacion,
    required this.conFoto,
  });

  final ClockEvidence evidence;
  final bool conUbicacion;
  final bool conFoto;
}

/// La escalera de evidencia del marcaje, en un solo lugar para las dos
/// pantallas que marcan — Hoy y Cuadrilla.
///
/// **La evidencia es la ubicación; la foto es lo que queda cuando no hay
/// ubicación.** Con GPS no se pide nada más. Sin GPS se abre la cámara — al
/// frente de obra, nunca un selfie. Sin cámara tampoco, se marca igual: la
/// escalera decide qué se pide, jamás qué se permite (regla 9).
class EvidenceCollector {
  const EvidenceCollector(this._location, this._camera, this._media);

  final DeviceLocation _location;
  final PhotoCapture _camera;
  final MediaRepository _media;

  Future<CollectedEvidence> collect({required String projectId}) async {
    final ubicacion = await _location.current();

    if (ubicacion.isOk) {
      return CollectedEvidence(
        evidence: ClockEvidence(
          lat: ubicacion.lat,
          lng: ubicacion.lng,
          isMockLocation: ubicacion.isMocked,
        ),
        conUbicacion: true,
        conFoto: false,
      );
    }

    // El segundo escalón: la foto del frente de obra. Registrarla nunca espera
    // a la red — el binario sube después, con reintento. Y **nada de esto puede
    // tumbar el marcaje** (regla 9): un archivo ilegible o una transacción que
    // falla cuentan como "sin foto", no como "sin jornada".
    String? photoId;
    try {
      final ruta = await _camera.takePhoto();
      if (ruta != null) {
        photoId = await _media.registerPhoto(
          projectId: projectId,
          filePath: ruta,
          // Lo más cerca del disparo que se puede sin leer EXIF: recién
          // vuelto de la cámara.
          capturedAt: DateTime.now(),
        );
      }
    } on Object {
      photoId = null;
    }

    return CollectedEvidence(
      evidence: ClockEvidence(photoId: photoId),
      conUbicacion: false,
      conFoto: photoId != null,
    );
  }
}

final evidenceCollectorProvider = Provider<EvidenceCollector>((ref) {
  return EvidenceCollector(
    ref.watch(deviceLocationProvider),
    ref.watch(photoCaptureProvider),
    ref.watch(mediaRepositoryProvider),
  );
});
