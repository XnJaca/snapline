import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los `.arb` como archivos, no como cadenas.
///
/// Un ARB es JSON: una clave repetida no falla, **gana la última y la primera
/// desaparece en silencio**. Pasó — `projectVisibilityStages` se definió dos
/// veces y el formulario de obra terminó mostrando el texto de un selector de
/// otra pantalla, sin que nada se rompiera ni ningún test lo notara.
void main() {
  final archivos = {
    'es': File('lib/l10n/app_es.arb'),
    'en': File('lib/l10n/app_en.arb'),
  };

  Map<String, dynamic> leer(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  List<String> claves(File f) => RegExp(r'^  "(@?[a-zA-Z][a-zA-Z0-9_]*)":',
          multiLine: true)
      .allMatches(f.readAsStringSync())
      .map((m) => m.group(1)!)
      .toList();

  for (final MapEntry(key: idioma, value: archivo) in archivos.entries) {
    test('$idioma: ninguna clave se define dos veces', () {
      final repetidas = <String>[];
      final vistas = <String>{};
      for (final clave in claves(archivo)) {
        if (!vistas.add(clave)) repetidas.add(clave);
      }

      expect(repetidas, isEmpty,
          reason: 'La segunda definición pisa a la primera sin avisar');
    });
  }

  test('los dos idiomas dicen las mismas claves', () {
    // Una clave que existe solo en español deja al usuario en inglés viendo el
    // texto en español, o un getter que no compila.
    final es = leer(archivos['es']!).keys.where((k) => !k.startsWith('@'));
    final en = leer(archivos['en']!).keys.where((k) => !k.startsWith('@'));

    expect(es.toSet().difference(en.toSet()), isEmpty,
        reason: 'faltan en inglés');
    expect(en.toSet().difference(es.toSet()), isEmpty,
        reason: 'faltan en español');
  });
}
