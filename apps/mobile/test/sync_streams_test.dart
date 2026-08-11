import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/sync_client.dart';
import 'package:snapline/api/models/address_dto.dart';
import 'package:snapline/api/models/sync_pull_response_dto.dart';
import 'package:snapline/api/models/sync_push_dto.dart';
import 'package:snapline/api/models/sync_push_response_dto.dart';
import 'package:snapline/api/models/sync_result_dto.dart';
import 'package:snapline/api/models/sync_result_dto_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/customer_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// El sincronizador escribe en Drift, y **la pantalla tiene que enterarse**.
///
/// Estos casos existen por un bug real: `_marcarSincronizada` usaba
/// `customStatement`, que deja la fila correcta en la base pero **no refresca
/// ningún stream**, porque Drift no sabe qué tabla tocó una sentencia cruda. En
/// la app se veía como que una escritura con señal quedaba marcada "guardado en
/// el teléfono" para siempre; volvía a la normalidad solo al reconstruir la
/// pantalla o reabrir la app.
///
/// Leer la base de nuevo —que es lo que hace un test común— **no lo detecta**:
/// hay que observar el stream, como hace la UI.
void main() {
  late AppDatabase db;
  late Outbox outbox;
  late CustomerRepository repo;

  const direccion = AddressDto(
    line1: '412 Ellsworth Dr',
    city: 'Silver Spring',
    state: 'MD',
    postalCode: '20910',
  );

  setUp(() {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
    repo = CustomerRepository(db, outbox, const Uuid());
  });

  tearDown(() => db.close());

  test('al aplicarse la operación, el stream emite la fila ya sincronizada', () async {
    final clienteId = await repo.create(
      const CustomerInput(displayName: 'Martínez'),
    );
    final siteId = await repo.addSite(clienteId, direccion);
    await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

    // La UI observa; no vuelve a consultar.
    final emisiones = <bool>[];
    final sub = repo.watchSites(clienteId).listen((sitios) {
      emisiones.add(sitios.single.pending);
    });
    await pumpEventQueue();
    expect(emisiones.last, isTrue, reason: 'nace pendiente');

    final pendientes = await outbox.pending();
    final sincronizador = Synchronizer(
      db,
      _SyncClientQueAplicaTodo(pendientes.map((op) => op.targetId).toList()),
      outbox,
    );
    await sincronizador.push();
    await pumpEventQueue();

    // Sin `updates` en el customUpdate, esta afirmación falla: la base queda
    // bien y el stream nunca vuelve a emitir.
    expect(
      emisiones.last,
      isFalse,
      reason: 'la pantalla tiene que enterarse sin reconstruirse',
    );
    await sub.cancel();
  });

  test('un borrado que llega del servidor saca la fila de la lista observada', () async {
    final clienteId = await repo.create(
      const CustomerInput(displayName: 'Martínez'),
    );
    final siteId = await repo.addSite(clienteId, direccion);

    final emisiones = <int>[];
    final sub = repo.watchSites(clienteId).listen((s) => emisiones.add(s.length));
    await pumpEventQueue();
    expect(emisiones.last, 1);

    final sincronizador = Synchronizer(
      db,
      _SyncClientQueBorra(siteId),
      outbox,
    );
    await sincronizador.pull();
    await pumpEventQueue();

    expect(
      emisiones.last,
      0,
      reason: 'la fila deja de listarse sin reconstruir la pantalla',
    );
    await sub.cancel();
  });
}

/// Responde `applied` a todo lo que se le mande.
class _SyncClientQueAplicaTodo implements SyncClient {
  _SyncClientQueAplicaTodo(this.targetIds);

  final List<String> targetIds;

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async {
    return SyncPushResponseDto(
      failed: 0,
      results: [
        for (final op in body.operations)
          SyncResultDto(
            clientId: op.clientId,
            status: SyncResultDtoStatus.applied,
            resourceId: op.targetId,
            code: null,
            message: null,
          ),
      ],
    );
  }

  @override
  Future<SyncPullResponseDto> syncPull({String? since}) async =>
      _pullVacio(borradosDeSitios: const []);
}

/// Devuelve un pull donde el sitio viene marcado como borrado.
class _SyncClientQueBorra implements SyncClient {
  _SyncClientQueBorra(this.siteId);

  final String siteId;

  @override
  Future<SyncPullResponseDto> syncPull({String? since}) async =>
      _pullVacio(borradosDeSitios: [siteId]);

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async =>
      SyncPushResponseDto(failed: 0, results: const []);
}

SyncPullResponseDto _pullVacio({required List<String> borradosDeSitios}) {
  return SyncPullResponseDto(
    serverTime: DateTime.utc(2026, 8, 11),
    customers: const [],
    sites: const [],
    projects: const [],
    assignments: const [],
    mediaAssets: const [],
    timeEntries: const [],
    crews: const [],
    crewMembers: const [],
    people: const [],
    deleted: {'sites': borradosDeSitios},
  );
}
