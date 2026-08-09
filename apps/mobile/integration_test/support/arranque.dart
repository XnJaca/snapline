import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapline/main.dart';

const password = 'Snapline123!';

/// Cada caso parte sin sesión y sin pestaña recordada: si no, el router entra
/// directo y nunca se ve la pantalla de login, o abre en un eje que dejó el
/// caso anterior.
Future<void> arrancarLimpio(WidgetTester tester) async {
  await const FlutterSecureStorage().delete(key: 'snapline.session');
  await SharedPreferencesAsync().remove('snapline.nav.lastDestination');

  await tester.pumpWidget(const ProviderScope(child: SnaplineApp()));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Vuelve a montar la app conservando lo guardado: es lo que pasa al reabrirla.
Future<void> reabrir(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(const ProviderScope(child: SnaplineApp()));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> entrar(WidgetTester tester, String identificador) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.first, identificador);
  await tester.enterText(campos.last, password);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// Quién está adentro vive en el menú de cuenta, que es de donde se sale.
Future<void> abrirCuenta(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
  await tester.pumpAndSettle();
}
