import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Dónde viven los binarios de las fotos en este teléfono.
///
/// **En la base se guarda el nombre del archivo, no la ruta.** En iOS el
/// contenedor de la app tiene un UUID que cambia en cada instalación, así que
/// una ruta absoluta guardada hoy apunta mañana a un directorio que ya no
/// existe: la foto se veía al tomarla y desaparecía al reinstalar. El nombre no
/// cambia nunca.
abstract final class MediaPaths {
  static String? _carpeta;

  /// Se resuelve una vez al arrancar. Después la lectura es síncrona, que es lo
  /// que necesita el stream de la galería.
  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(docs.path, 'media'));
    if (!carpeta.existsSync()) carpeta.createSync(recursive: true);
    _carpeta = carpeta.path;
  }

  /// Solo para los tests, que no tienen `path_provider`.
  static void usarCarpeta(String ruta) => _carpeta = ruta;

  /// El nombre con el que se guarda en la base.
  static String nombreDe(String rutaONombre) => p.basename(rutaONombre);

  /// La ruta de hoy para un archivo guardado.
  ///
  /// Tolera que venga una ruta absoluta vieja: se queda con el nombre y lo
  /// resuelve contra la carpeta actual, así las filas de antes de este cambio
  /// vuelven a encontrar su archivo en vez de quedar rotas para siempre.
  static String? absoluta(String rutaONombre) {
    final carpeta = _carpeta;
    if (carpeta == null) return null;
    return p.join(carpeta, p.basename(rutaONombre));
  }

  /// Borra el binario de una foto que se tomó y no se llegó a registrar.
  /// No pasa por el borrado suave porque no hay fila que dar de baja.
  static Future<void> descartar(String rutaONombre) async {
    final ruta = absoluta(rutaONombre);
    if (ruta == null) return;
    final archivo = File(ruta);
    if (archivo.existsSync()) await archivo.delete();
  }

  /// Si el archivo está de verdad. Una ruta guardada no garantiza nada: el
  /// sistema limpia, la app se reinstala, alguien borra.
  static bool existe(String rutaONombre) {
    final ruta = absoluta(rutaONombre);
    return ruta != null && File(ruta).existsSync();
  }
}
