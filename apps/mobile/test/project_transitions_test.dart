import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/project_status.dart';
import 'package:snapline/features/projects/project_transitions.dart';

/// La tabla de transiciones del móvil contra la del API.
///
/// El selector de estado ofrece solo las transiciones válidas, y **el servidor las
/// valida por su cuenta**. Si las dos tablas divergen, el móvil ofrece un cambio
/// que el servidor rechaza y el error aparece recién al sincronizar, en un lugar
/// donde nadie lo está mirando.
///
/// No sale del contrato porque es lógica y no un DTO, así que la paridad se
/// verifica leyendo el archivo del API.
void main() {
  test('coincide con la tabla de apps/api', () {
    final fuente = File(
      '../api/src/projects/project-status.ts',
    ).readAsStringSync();

    final delApi = _parsear(fuente);

    expect(
      delApi,
      isNotEmpty,
      reason: 'si el parseo no encontró nada, este test no está comparando nada',
    );
    expect(delApi.keys.toSet(), _porNombre(projectTransitions).keys.toSet());
    expect(_porNombre(projectTransitions), delApi);
  });

  test('todo estado del contrato está en la tabla', () {
    // Un estado nuevo en el servidor sin entrada acá dejaría una obra sin poder
    // cambiar de estado, en silencio.
    for (final estado in ProjectStatus.$valuesDefined) {
      expect(
        projectTransitions.containsKey(estado),
        isTrue,
        reason: 'falta ${estado.json} en projectTransitions',
      );
    }
  });

  test('terminada y cancelada no tienen salida', () {
    expect(nextStatusesFor(ProjectStatus.completed), isEmpty);
    expect(nextStatusesFor(ProjectStatus.cancelled), isEmpty);
  });
}

/// `PROJECT_TRANSITIONS` del TypeScript, como mapa de nombres del contrato.
Map<String, List<String>> _parsear(String ts) {
  final bloque = RegExp(
    r'PROJECT_TRANSITIONS\s*=\s*\{(.*?)\n\}',
    dotAll: true,
  ).firstMatch(ts);
  if (bloque == null) return {};

  final resultado = <String, List<String>>{};
  final fila = RegExp(r'(\w+):\s*\[([^\]]*)\]', dotAll: true);
  for (final m in fila.allMatches(bloque.group(1)!)) {
    final destinos = m
        .group(2)!
        .split(',')
        .map((s) => s.replaceAll(RegExp("['\"\\s]"), ''))
        .where((s) => s.isNotEmpty)
        .toList();
    resultado[m.group(1)!] = destinos;
  }
  return resultado;
}

Map<String, List<String>> _porNombre(
  Map<ProjectStatus, List<ProjectStatus>> tabla,
) {
  return {
    for (final entrada in tabla.entries)
      entrada.key.json!: entrada.value.map((e) => e.json!).toList(),
  };
}
