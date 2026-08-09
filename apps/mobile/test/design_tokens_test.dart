import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/core/theme/tokens.dart';

/// `design-tokens.json` en la raíz del monorepo es la fuente única (ADR-0009), y
/// `tokens.dart` se traduce **a mano** hasta que exista el generador (DEBT-0001).
///
/// Estos tests son lo que hace vivible esa deuda: sin ellos, cambiar un color en
/// el JSON y olvidar el Dart no rompe nada — solo hace que la app se vea distinta
/// del panel, en silencio.
void main() {
  final json =
      jsonDecode(File('../../design-tokens.json').readAsStringSync())
          as Map<String, Object?>;
  final colores = json['color']! as Map<String, Object?>;

  Map<String, Object?> tema(String nombre) =>
      colores[nombre]! as Map<String, Object?>;

  Color desdeHex(String hex) =>
      Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

  double luminancia(Color c) => c.computeLuminance();

  double contraste(Color a, Color b) {
    final claro = math.max(luminancia(a), luminancia(b));
    final oscuro = math.min(luminancia(a), luminancia(b));
    return (claro + 0.05) / (oscuro + 0.05);
  }

  // Cada par es texto sobre fondo. La app se usa en un techo con sol directo:
  // acá el contraste no es accesibilidad formal, es si se lee o no.
  const pares = <List<String>>[
    ['on-primary', 'primary'],
    ['on-primary-container', 'primary-container'],
    // El label de la pestaña activa queda fuera de la pastilla, sobre la barra.
    ['on-primary-container', 'surface'],
    ['on-warning', 'warning'],
    ['on-warning-container', 'warning-container'],
    ['on-danger', 'danger'],
    ['on-danger-container', 'danger-container'],
    ['on-success', 'success'],
    ['on-success-container', 'success-container'],
    ['on-surface', 'surface'],
    ['on-surface', 'background'],
    ['on-surface', 'surface-variant'],
    ['text-muted', 'surface'],
    ['text-muted', 'background'],
    ['text-muted', 'surface-variant'],
    ['primary', 'surface'],
    ['danger', 'surface'],
    ['warning', 'surface'],
    ['success', 'surface'],
  ];

  group('contraste de design-tokens.json', () {
    for (final nombre in ['light', 'dark']) {
      for (final par in pares) {
        test('$nombre: ${par[0]} sobre ${par[1]} pasa AA', () {
          final t = tema(nombre);
          final ratio = contraste(
            desdeHex(t[par[0]]! as String),
            desdeHex(t[par[1]]! as String),
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${par[0]} sobre ${par[1]} en $nombre da '
                '${ratio.toStringAsFixed(2)}:1, por debajo de AA',
          );
        });
      }
    }
  });

  // El generador de DEBT-0001 todavía no existe: esto lo reemplaza mientras tanto.
  group('tokens.dart no se separó del JSON', () {
    test('los colores del tema claro coinciden', () {
      final t = tema('light');
      expect(LightTokens.primary, desdeHex(t['primary']! as String));
      expect(LightTokens.surface, desdeHex(t['surface']! as String));
      expect(LightTokens.background, desdeHex(t['background']! as String));
      expect(LightTokens.textMuted, desdeHex(t['text-muted']! as String));
      expect(LightTokens.danger, desdeHex(t['danger']! as String));
      expect(LightTokens.warning, desdeHex(t['warning']! as String));
      expect(LightTokens.success, desdeHex(t['success']! as String));
      expect(
        LightTokens.warningContainer,
        desdeHex(t['warning-container']! as String),
      );
    });

    test('los colores del tema oscuro coinciden', () {
      final t = tema('dark');
      expect(DarkTokens.primary, desdeHex(t['primary']! as String));
      expect(DarkTokens.surface, desdeHex(t['surface']! as String));
      expect(DarkTokens.background, desdeHex(t['background']! as String));
      expect(DarkTokens.textMuted, desdeHex(t['text-muted']! as String));
      expect(DarkTokens.danger, desdeHex(t['danger']! as String));
      expect(DarkTokens.warning, desdeHex(t['warning']! as String));
      expect(DarkTokens.success, desdeHex(t['success']! as String));
    });

    test('el espaciado y los radios coinciden', () {
      final space = json['space']! as Map<String, Object?>;
      final radius = json['radius']! as Map<String, Object?>;
      expect(Tokens.space1, (space['1']! as num).toDouble());
      expect(Tokens.space4, (space['4']! as num).toDouble());
      expect(Tokens.space6, (space['6']! as num).toDouble());
      expect(Tokens.radiusMd, (radius['md']! as num).toDouble());
      expect(Tokens.radiusFull, (radius['full']! as num).toDouble());
    });
  });
}
