import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/arranque.dart';

/// SPEC-0003 contra el API de verdad. Lo que los tests de unidad no pueden
/// probar: que el rol y los permisos que arman la barra son los que el servidor
/// devuelve, y no los que el móvil supone.
///
///   pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev
///   cd apps/mobile && flutter test integration_test/navigation_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  List<String> ejes(WidgetTester tester) {
    return tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destino) => destino.label)
        .toList();
  }

  testWidgets('el dueño ve ejes de negocio, no de jornada', (tester) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');

    expect(ejes(tester), ['Projects', 'Customers', 'Reports', 'Billing']);
    // Fotos y Horas viven dentro de cada obra.
    expect(ejes(tester), isNot(contains('Photos')));
    expect(ejes(tester), isNot(contains('Hours')));
  });

  testWidgets('el trabajador ve dos pestañas y ninguna es la cartera', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, '+15551234567');

    expect(ejes(tester), ['Hoy', 'Fotos']);
  });

  testWidgets('entrar a una obra abre su contenedor de tabs', (tester) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');

    await tester.tap(find.text('Sample project 1'));
    await tester.pumpAndSettle();

    for (final tab in ['Progress', 'Photos', 'Hours', 'Details']) {
      expect(find.widgetWithText(Tab, tab), findsOneWidget);
    }
  });

  testWidgets('reabrir la app vuelve a la última pestaña usada', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');

    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Billing'), findsOneWidget);

    // Arrancar de nuevo sin borrar nada: es lo que pasa al reabrir.
    await reabrir(tester);

    expect(find.widgetWithText(AppBar, 'Billing'), findsOneWidget);
  });
}
