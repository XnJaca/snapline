import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapline/api/models/address_dto.dart';
import 'package:snapline/api/models/project_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/customer_repository.dart';
import 'package:snapline/data/repositories/project_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';

import 'support/arranque.dart';

/// SPEC-0005 contra el API de verdad.
///
/// Lo que ningún test de unidad puede probar: que la obra creada sin señal llegue
/// con el id del teléfono, y que **una transición retrocedente que llega tarde la
/// descarte el servidor** — es lo único de `project` que no es última escritura
/// gana, y el dispositivo no puede decidirlo porque no sabe si su estado es viejo.
///
///   pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev
///   cd apps/mobile && flutter test integration_test/projects_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const direccion = AddressDto(
    line1: '9800 Georgia Ave',
    city: 'Silver Spring',
    state: 'MD',
    postalCode: '20902',
  );

  ProviderContainer contenedorDe(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
        listen: false,
      );

  testWidgets('la obra creada sin señal llega con el id del teléfono', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final contenedor = contenedorDe(tester);
    final clientes = contenedor.read(customerRepositoryProvider);
    final obras = contenedor.read(projectRepositoryProvider);
    final sincronizador = contenedor.read(synchronizerProvider);
    final db = contenedor.read(appDatabaseProvider);

    // El trío completo, como si se cargara parado en la obra sin cobertura.
    final customerId = await clientes.create(
      const CustomerInput(displayName: 'Cliente de obra'),
    );
    final siteId = await clientes.addSite(customerId, direccion);
    final projectId = await obras.create(
      ProjectInput(
        customerId: customerId,
        siteId: siteId,
        name: 'Obra de SPEC-0005',
        status: ProjectStatus.scheduled,
      ),
    );

    expect(await contenedor.read(outboxProvider).pending(), hasLength(3));
    expect(await sincronizador.push(), isTrue);
    expect(
      await contenedor.read(outboxProvider).pending(),
      isEmpty,
      reason: 'si la obra hubiera llegado antes que su cliente, quedaría encolada',
    );

    expect(await sincronizador.pull(), isTrue);
    final obra = await (db.select(
      db.projects,
    )..where((p) => p.id.equals(projectId))).getSingle();
    expect(obra.name, 'Obra de SPEC-0005');
    expect(obra.customerId, customerId);
    expect(obra.syncStatus, SyncStatus.synced);
    // Nace en etapas y el servidor no lo cambia.
    expect(obra.clientVisibilityMode, 'STAGES');
  });

  testWidgets('el retroceso que llega tarde lo descarta el servidor', (
    tester,
  ) async {
    await arrancarLimpio(tester);
    await entrar(tester, 'william@pcdmv.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final contenedor = contenedorDe(tester);
    final clientes = contenedor.read(customerRepositoryProvider);
    final obras = contenedor.read(projectRepositoryProvider);
    final sincronizador = contenedor.read(synchronizerProvider);
    final db = contenedor.read(appDatabaseProvider);

    final customerId = await clientes.create(
      const CustomerInput(displayName: 'Cliente del retroceso'),
    );
    final siteId = await clientes.addSite(customerId, direccion);
    final projectId = await obras.create(
      ProjectInput(
        customerId: customerId,
        siteId: siteId,
        name: 'Obra que avanza',
        status: ProjectStatus.scheduled,
      ),
    );
    expect(await sincronizador.push(), isTrue);

    // La obra avanza hasta terminada: es lo que pasó "mientras el teléfono no
    // tenía señal".
    for (final estado in [ProjectStatus.inProgress, ProjectStatus.completed]) {
      await obras.changeStatus(projectId, estado);
      expect(await sincronizador.push(), isTrue);
    }

    // Y ahora llega la orden vieja: volver a agendada. El dispositivo no puede
    // saber que la obra ya se entregó.
    await contenedor.read(outboxProvider).enqueue(
      type: SyncOp.projectUpdate,
      targetId: projectId,
      payload: {
        'status': ProjectStatus.scheduled.json,
        'serviceType': 'lo demás sí se aplica',
      },
    );

    expect(await sincronizador.push(), isTrue);
    expect(
      await contenedor.read(outboxProvider).pending(),
      isEmpty,
      reason: 'se descarta sin fallar, o se reintentaría para siempre',
    );

    expect(await sincronizador.pull(), isTrue);
    final obra = await (db.select(
      db.projects,
    )..where((p) => p.id.equals(projectId))).getSingle();
    expect(
      obra.status,
      ProjectStatus.completed.json,
      reason: 'el servidor descartó la transición retrocedente',
    );
    expect(
      obra.serviceType,
      'lo demás sí se aplica',
      reason: 'lo que llegó tarde es el estado, no las otras correcciones',
    );
  });
}
