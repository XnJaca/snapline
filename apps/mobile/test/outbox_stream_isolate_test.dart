import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/address_dto.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/customer_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

/// El contador de la bandeja tiene que emitir cuando se encola, **con el
/// ejecutor real**: la app abre la base con `driftDatabase()`, que corre en un
/// isolate de fondo, y ahí las notificaciones se comportan distinto que en la
/// base en memoria de los demás tests.
///
/// Existe por un bug que solo se veía en el teléfono: encolar dentro de la
/// transacción de un repositorio no despertaba al contador, así que el
/// sincronizador nunca se enteraba y la operación quedaba "guardado en el
/// teléfono" hasta el próximo arranque. En memoria no se reproducía.
void main() {
  late Directory dir;
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
    dir = Directory.systemTemp.createTempSync('snapline_isolate_test');
    // El mismo tipo de ejecutor que usa la app: la base en otro isolate.
    db = AppDatabase(
      NativeDatabase.createInBackground(File('${dir.path}/db.sqlite')),
    );
    outbox = Outbox(db, const Uuid());
    repo = CustomerRepository(db, outbox, const Uuid());
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('encolar directo despierta al contador', () async {
    final emisiones = <int>[];
    final sub = outbox.watchPendingCount().listen(emisiones.add);
    // Con la base en otro isolate la primera emisión también tarda.
    await _esperarEmision(() => emisiones.isNotEmpty);
    expect(emisiones.last, 0);

    await outbox.enqueue(
      type: SyncOp.siteUpdate,
      targetId: '019feef4-94d8-76fd-b6ee-0e67fc698213',
      payload: {'lat': 1.0},
    );
    await _esperarEmision(() => emisiones.last == 1);

    expect(emisiones.last, 1);
    await sub.cancel();
  });

  test('encolar dentro de la transacción del repositorio también', () async {
    final clienteId = await repo.create(const CustomerInput(displayName: 'M'));
    final siteId = await repo.addSite(clienteId, direccion);

    final emisiones = <int>[];
    final sub = outbox.watchPendingCount().listen(emisiones.add);
    await _esperarEmision(() => emisiones.isNotEmpty);
    final antes = emisiones.last;

    await repo.setSiteLocation(siteId, lat: 9.9281, lng: -84.0907);
    await _esperarEmision(() => emisiones.last == antes + 1);

    expect(
      emisiones.last,
      antes + 1,
      reason: 'la pantalla del bug: encolar no despertaba al sincronizador',
    );
    await sub.cancel();
  });
}

/// Con la base en otro isolate las notificaciones no llegan en el mismo tick:
/// se espera con tope en vez de un solo `pumpEventQueue`.
Future<void> _esperarEmision(bool Function() listo) async {
  for (var i = 0; i < 100 && !listo(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
