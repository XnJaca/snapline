import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';

/// Preferencia de tema. Arranca en `system` porque la app se usa tanto en un
/// techo con sol como en un sótano.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void select(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Idioma elegido por el usuario. `null` sigue al del dispositivo.
///
/// El locale es por usuario y no por empresa: William administra en inglés y sus
/// trabajadores probablemente usen la app en español, en la misma cuenta.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void select(Locale? locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// El idioma que finalmente usa la app: manda lo que el usuario eligió en la
/// app y, si no eligió nada, el `locale` de su cuenta.
///
/// Sale de la sesión guardada, así que reabrir sin señal conserva el idioma del
/// último login en vez de caer al del dispositivo.
final effectiveLocaleProvider = Provider<Locale?>((ref) {
  final elegido = ref.watch(localeProvider);
  if (elegido != null) return elegido;

  final session = ref.watch(sessionControllerProvider).value;
  // `json` es nulo cuando el servidor manda un locale que esta versión de la app
  // todavía no conoce: ahí se cae al idioma del dispositivo en vez de romper.
  final code = session?.user.locale.json;
  return code == null ? null : Locale(code);
});
