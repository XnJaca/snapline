import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ninguna pantalla habla con la red.
///
/// La UI lee de Drift y escribe en Drift; el único que toca el API es el
/// sincronizador. Un widget que llame a un cliente generado funciona con señal y
/// deja la pantalla vacía sin ella, y eso se descubre en la obra y no acá.
///
/// Los **modelos** de `lib/api/models/` sí se usan: son el contrato, y tener un
/// segundo tipo de dirección o de estado en paralelo es cómo divergen.
void main() {
  test('ninguna pantalla importa un cliente de lib/api/', () {
    final ofensores = <String>[];

    for (final archivo in _dartFiles('lib/features')) {
      final contenido = archivo.readAsStringSync();
      final lineas = contenido.split('\n');

      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (!linea.trimLeft().startsWith('import ')) continue;
        if (_importaCliente(linea)) {
          ofensores.add('${archivo.path} → línea ${i + 1}: ${linea.trim()}');
        }
      }
    }

    expect(
      ofensores,
      isEmpty,
      reason:
          'Estas pantallas hablan con la red. La escritura va por el '
          'repositorio y la bandeja de salida; la lectura, por Drift.',
    );
  });

  test('el sincronizador sí puede, y es el único que lo hace', () {
    // Contraprueba: si esto dejara de encontrarlo, el test de arriba estaría
    // pasando porque no está mirando nada.
    final sincronizador = File(
      'lib/data/sync/synchronizer.dart',
    ).readAsStringSync();

    expect(sincronizador, contains("import '../../api/clients/sync_client.dart'"));
  });
}

bool _importaCliente(String linea) =>
    linea.contains('api/clients/') || linea.contains("package:snapline/api/clients/");

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));
