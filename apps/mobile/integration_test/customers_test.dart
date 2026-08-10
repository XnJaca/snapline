import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapline/api/models/address_dto.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/customer_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';
import 'package:uuid/uuid.dart';

import 'support/arranque.dart';

/// SPEC-0006 contra el API de verdad.
///
/// Es lo único que prueba lo que los tests de unidad no pueden: que el id que
/// genera el teléfono sea el que queda en el servidor, y que **cliente,
/// propiedad y obra creados sin señal en ese orden lleguen en ese orden**. El
/// spec lo dice sin rodeos: si esto no funciona, el prototipo no sirve.
///
///   pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev
///   cd apps/mobile && flutter test integration_test/customers_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const direccion = AddressDto(
    line1: '9800 Georgia Ave',
    city: 'Silver Spring',
    state: 'MD',
    postalCode: '20902',
  );

  /// El contenedor de la app ya andando, para llegar a los repositorios.
  ProviderContainer contenedorDe(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
        listen: false,
      );

  testWidgets('cliente, propiedad y obra sin señal llegan en ese orden', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final contenedor = contenedorDe(tester);
    final repo = contenedor.read(customerRepositoryProvider);
    final outbox = contenedor.read(outboxProvider);
    final sincronizador = contenedor.read(synchronizerProvider);
    final db = contenedor.read(appDatabaseProvider);

    // Los tres, como si se hubieran cargado parado en la obra sin cobertura.
    final customerId = await repo.create(
      const CustomerInput(
        displayName: 'Cliente de integración',
        phone: '+13015550199',
      ),
    );
    final siteId = await repo.addSite(customerId, direccion);
    final projectId = const Uuid().v7();
    await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: projectId,
      payload: {
        'customerId': customerId,
        'siteId': siteId,
        'name': 'Obra de integración',
        'status': 'IN_PROGRESS',
      },
    );

    expect(await outbox.pending(), hasLength(3));
    expect(await sincronizador.push(), isTrue);
    // Las tres aplicadas: si el servidor hubiera recibido la propiedad antes que
    // su cliente, la habría rechazado y quedaría encolada.
    expect(
      await outbox.pending(),
      isEmpty,
      reason: 'una operación que falló quedaría en la cola con su motivo',
    );

    expect(await sincronizador.pull(), isTrue);

    // El id del dispositivo es el que quedó en el servidor: lo que baja del
    // pull trae el mismo, y por eso la fila pasa a SYNCED en vez de duplicarse.
    final cliente = await (db.select(
      db.customers,
    )..where((c) => c.id.equals(customerId))).getSingle();
    expect(cliente.displayName, 'Cliente de integración');
    expect(cliente.syncStatus, SyncStatus.synced);

    final sitio = await (db.select(
      db.sites,
    )..where((s) => s.id.equals(siteId))).getSingle();
    expect(sitio.customerId, customerId);
    expect(sitio.syncStatus, SyncStatus.synced);

    final obra = await (db.select(
      db.projects,
    )..where((p) => p.id.equals(projectId))).getSingle();
    expect(obra.customerId, customerId);
    expect(obra.siteId, siteId);
  });

  testWidgets('corregir un cliente y su dirección llega sin duplicar', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final contenedor = contenedorDe(tester);
    final repo = contenedor.read(customerRepositoryProvider);
    final sincronizador = contenedor.read(synchronizerProvider);
    final db = contenedor.read(appDatabaseProvider);

    final customerId = await repo.create(
      const CustomerInput(displayName: 'Antes de corregir'),
    );
    final siteId = await repo.addSite(customerId, direccion);
    expect(await sincronizador.push(), isTrue);

    // Las dos correcciones, encoladas sin señal.
    await repo.update(
      customerId,
      const CustomerInput(
        displayName: 'Después de corregir',
        phone: '+13015550200',
      ),
    );
    await repo.updateSite(
      siteId,
      const AddressDto(
        line1: '412 Ellsworth Dr',
        city: 'Silver Spring',
        state: 'MD',
        postalCode: '20910',
      ),
    );

    expect(await sincronizador.push(), isTrue);
    expect(await sincronizador.pull(), isTrue);

    // Una sola fila por recurso: la corrección se aplicó encima, no al lado.
    final clientes = await (db.select(
      db.customers,
    )..where((c) => c.id.equals(customerId))).get();
    expect(clientes, hasLength(1));
    expect(clientes.first.displayName, 'Después de corregir');
    expect(clientes.first.phone, '+13015550200');

    final sitios = await (db.select(
      db.sites,
    )..where((s) => s.id.equals(siteId))).get();
    expect(sitios, hasLength(1));
    // La dirección vuelve del servidor con sus seis campos y no vacía: es lo que
    // el `AddressDto` del contrato garantiza.
    expect(sitios.first.address, contains('412 Ellsworth Dr'));
    expect(sitios.first.address, contains('20910'));
  });
}
