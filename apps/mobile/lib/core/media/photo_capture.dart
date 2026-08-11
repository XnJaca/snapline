import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Abre la cámara y devuelve la ruta del archivo guardado, o `null` si la
/// persona canceló o no hay permiso.
///
/// **Captura directa, sin galería, a propósito**: `ImageSource.camera` no
/// ofrece elegir una foto vieja, que es el fraude realista del marcaje. La
/// negativa no bloquea nada — la escalera sigue y el servidor pone `NO_PHOTO`.
abstract class PhotoCapture {
  Future<String?> takePhoto();
}

class ImagePickerPhotoCapture implements PhotoCapture {
  const ImagePickerPhotoCapture();

  @override
  Future<String?> takePhoto() async {
    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        // Acotada: es evidencia, no portafolio. La captura de obra para
        // publicar tiene su propio spec y su propia calidad.
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (foto == null) return null;

      // Del directorio temporal a uno propio: el sistema limpia tmp cuando
      // quiere, y esta foto puede esperar días por señal.
      final docs = await getApplicationDocumentsDirectory();
      final destinoDir = Directory(p.join(docs.path, 'media'));
      await destinoDir.create(recursive: true);
      final destino = p.join(destinoDir.path, p.basename(foto.path));
      await File(foto.path).copy(destino);
      return destino;
    } on Object {
      // Sin permiso de cámara o cámara rota: cuenta como "sin foto". La regla 9
      // no permite que esto detenga un marcaje.
      return null;
    }
  }
}

final photoCaptureProvider = Provider<PhotoCapture>(
  (ref) => const ImagePickerPhotoCapture(),
);
