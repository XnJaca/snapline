import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';
import 'package:uuid/uuid.dart';

import 'support/arranque.dart';

/// La bandeja de salida contra el API de verdad.
///
/// Es lo único que prueba lo que promete el goal del spec: que una escritura
/// hecha sin señal llegue al servidor **exactamente una vez**.
///
///   pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev
///   cd apps/mobile && flutter test integration_test/outbox_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lo encolado sin señal llega al servidor una sola vez', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    final outbox = contenedor.read(outboxProvider);
    final sincronizador = contenedor.read(synchronizerProvider);

    // Un cliente creado con el id que genera el dispositivo, como si se hubiera
    // cargado parado en la obra.
    final customerId = const Uuid().v7();
    final clientId = await outbox.enqueue(
      type: SyncOp.customerCreate,
      targetId: customerId,
      payload: {'displayName': 'Cliente de bandeja'},
    );
    expect(await outbox.pending(), hasLength(1));

    expect(await sincronizador.push(), isTrue);
    expect(
      await outbox.pending(),
      isEmpty,
      reason: 'lo aplicado tiene que salir de la cola',
    );

    // El caso real de la regla 19: el servidor la aplicó pero se cortó la red
    // antes de que llegara la respuesta, así que sigue en la cola **con la
    // misma clave** y se manda otra vez.
    await outbox.enqueue(
      clientId: clientId,
      type: SyncOp.customerCreate,
      targetId: customerId,
      payload: {'displayName': 'Cliente de bandeja'},
    );
    expect(await sincronizador.push(), isTrue);
    expect(await outbox.pending(), isEmpty);

    // Y al bajar, el cliente está una sola vez.
    expect(await sincronizador.pull(), isTrue);
    final db = contenedor.read(appDatabaseProvider);
    final clientes = await db.select(db.customers).get();
    final coincidencias = clientes.where((c) => c.id == customerId);
    expect(coincidencias, hasLength(1));
    expect(coincidencias.first.displayName, 'Cliente de bandeja');
  });
}
