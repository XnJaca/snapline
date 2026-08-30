import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Para qué se toma la foto, que decide con cuánta calidad se guarda.
///
/// No es una preferencia: la de evidencia se mira una vez y pesa lo menos
/// posible; la de obra termina en la web de William y en sus redes, donde se ve
/// grande.
enum PhotoQuality {
  /// Marcaje. Se mira para verificar que alguien estaba ahí.
  evidence(maxWidth: 2048, quality: 85),

  /// Obra. Candidata a `PUBLIC` y a los pares antes/después.
  portfolio(maxWidth: 3024, quality: 90);

  const PhotoQuality({required this.maxWidth, required this.quality});

  final double maxWidth;
  final int quality;
}

/// Por qué no se pudo tomar la foto.
///
/// Distinguir el permiso del resto importa: es lo único que la persona puede
/// arreglar, y arreglarlo está en los ajustes del sistema, no en la app.
enum PhotoFailure { cancelled, permissionDenied, failed }

class PhotoResult {
  const PhotoResult.taken(this.path) : failure = null;
  const PhotoResult.failed(this.failure) : path = null;

  final String? path;
  final PhotoFailure? failure;

  bool get ok => path != null;
}

/// Abre la cámara y devuelve la ruta del archivo guardado.
///
/// **Captura directa, sin galería, a propósito**: `ImageSource.camera` no
/// ofrece elegir una foto vieja, que es el fraude realista del marcaje.
abstract class PhotoCapture {
  /// El camino del marcaje: la negativa no bloquea nada y devuelve `null`. La
  /// escalera sigue y el servidor pone `NO_PHOTO` (regla 9).
  Future<String?> takePhoto();

  /// El camino de la obra, que sí necesita saber por qué falló para poder
  /// decirlo: acá tomar la foto es la acción entera de la pantalla.
  Future<PhotoResult> capture(PhotoQuality calidad);
}

class ImagePickerPhotoCapture implements PhotoCapture {
  const ImagePickerPhotoCapture();

  @override
  Future<String?> takePhoto() async {
    final resultado = await capture(PhotoQuality.evidence);
    return resultado.path;
  }

  @override
  Future<PhotoResult> capture(PhotoQuality calidad) async {
    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: calidad.maxWidth,
        imageQuality: calidad.quality,
      );
      if (foto == null) return const PhotoResult.failed(PhotoFailure.cancelled);

      // Del directorio temporal a uno propio: el sistema limpia tmp cuando
      // quiere, y esta foto puede esperar días por señal.
      final docs = await getApplicationDocumentsDirectory();
      final destinoDir = Directory(p.join(docs.path, 'media'));
      await destinoDir.create(recursive: true);
      final destino = p.join(destinoDir.path, p.basename(foto.path));
      await File(foto.path).copy(destino);
      return PhotoResult.taken(destino);
    } on PlatformException catch (e) {
      // `image_picker` lo reporta así en las dos plataformas.
      final sinPermiso = e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied';
      return PhotoResult.failed(
          sinPermiso ? PhotoFailure.permissionDenied : PhotoFailure.failed);
    } on Object {
      return const PhotoResult.failed(PhotoFailure.failed);
    }
  }
}

final photoCaptureProvider = Provider<PhotoCapture>(
  (ref) => const ImagePickerPhotoCapture(),
);
