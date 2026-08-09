import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'support/arranque.dart';

/// Login contra el API de verdad. Cierra los criterios del SPEC-0001 que no se
/// pueden verificar con mocks: que se entre indistintamente con teléfono o con
/// email, que la app tome el idioma del usuario, y que cerrar sesión limpie.
///
/// Necesita el backend arriba y sembrado:
///
///   pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev
///   cd apps/mobile && flutter test integration_test/login_test.dart
///
/// Usuarios del seed (`apps/api/src/database/seeds/dev.seed.ts`):
///   William  william@pcdmv.com  locale en  OWNER
///   Carlos   +15551234567       locale es  WORKER
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('un trabajador entra con su teléfono y ve la app en español', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, '+15551234567');

    // Su barra, en su idioma: el locale sale de la cuenta, no del dispositivo.
    expect(find.widgetWithText(AppBar, 'Hoy'), findsOneWidget);
    expect(find.text('Fotos'), findsWidgets);

    await abrirCuenta(tester);
    expect(find.textContaining('Carlos Ramírez'), findsOneWidget);
    expect(find.textContaining('Professional Construction LLC'), findsOneWidget);
  });

  testWidgets('el mismo teléfono entra escrito sin formato', (tester) async {
    await arrancarLimpio(tester);
    await entrar(tester, '5551234567');

    expect(find.widgetWithText(AppBar, 'Hoy'), findsOneWidget);
  });

  testWidgets('el admin entra con su correo y ve la app en inglés', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');

    expect(find.text('Projects'), findsWidgets);

    await abrirCuenta(tester);
    expect(find.textContaining('William Ferman'), findsOneWidget);
    expect(find.textContaining('Signed in as'), findsOneWidget);
  });

  testWidgets('una contraseña incorrecta no se confunde con falta de red', (
    tester,
  ) async {
    await arrancarLimpio(tester);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.first, 'william@pcdmv.com');
    await tester.enterText(campos.last, 'claveIncorrecta1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining('Incorrect'), findsOneWidget);
    expect(find.textContaining('No connection'), findsNothing);
  });

  testWidgets('cerrar sesión borra la sesión guardada y vuelve al login', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');

    await abrirCuenta(tester);
    expect(find.textContaining('William Ferman'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sin sesión no hay `user.locale`, así que la app vuelve al idioma del
    // dispositivo: el texto del botón depende de eso y no sirve para afirmar.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      await const FlutterSecureStorage().read(key: 'snapline.session'),
      isNull,
    );
  });
}
