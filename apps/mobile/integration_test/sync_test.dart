import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/arranque.dart';

/// La capa local contra el API de verdad.
///
/// Lo que los tests de unidad no pueden probar: que lo que baja del servidor
/// entre a Drift y que la pantalla lo muestre.
///
///   pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev
///   cd apps/mobile && flutter test integration_test/sync_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la cartera muestra lo que bajó', (tester) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Techo Martinez'), findsOneWidget);
  });
}
