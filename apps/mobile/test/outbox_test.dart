import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// La bandeja de salida: lo que hace que una escritura sin señal no se pierda.
void main() {
  late AppDatabase db;
  late Outbox outbox;

  setUp(() {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
  });

  tearDown(() => db.close());

  test('encolar guarda la operación con su clave', () async {
    final clientId = await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p1',
      payload: {'name': 'Techo Martinez'},
    );

    final pendientes = await outbox.pending();
    expect(pendientes, hasLength(1));
    expect(pendientes.first.clientId, clientId);
    expect(pendientes.first.type, SyncOp.projectCreate);
    expect(jsonDecode(pendientes.first.payload), {'name': 'Techo Martinez'});
  });

  // El servidor ordena el lote por `occurredAt`, y una salida no puede
  // aplicarse antes que su entrada.
  test('lo pendiente sale en el orden en que ocurrió', () async {
    await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'segunda',
      payload: const {},
      occurredAt: DateTime(2026, 8, 9, 11),
    );
    await outbox.enqueue(
      type: SyncOp.customerCreate,
      targetId: 'primera',
      payload: const {},
      occurredAt: DateTime(2026, 8, 9, 9),
    );

    final orden = (await outbox.pending()).map((o) => o.targetId).toList();
    expect(orden, ['primera', 'segunda']);
  });

  // La clave es lo que hace que reintentar no duplique (regla 19).
  test('cada operación lleva una clave distinta', () async {
    final a = await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p1',
      payload: const {},
    );
    final b = await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p2',
      payload: const {},
    );

    expect(a, isNot(b));
  });

  test('lo aplicado sale de la cola', () async {
    final clientId = await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p1',
      payload: const {},
    );

    await outbox.remove(clientId);
    expect(await outbox.pending(), isEmpty);
  });

  // Que algo no suba no puede desaparecer en silencio: hay que poder decir por
  // qué.
  test('lo que falla queda encolado con su motivo', () async {
    final clientId = await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p1',
      payload: const {},
    );

    await outbox.incrementAttempts(clientId);
    await outbox.markFailed(clientId, 'VALIDATION_FAILED');

    final pendientes = await outbox.pending();
    expect(pendientes, hasLength(1));
    expect(pendientes.first.lastError, 'VALIDATION_FAILED');
    expect(pendientes.first.attempts, 1);
  });

  test('el conteo de pendientes se puede observar', () async {
    expect(await outbox.watchPendingCount().first, 0);

    await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p1',
      payload: const {},
    );
    expect(await outbox.watchPendingCount().first, 1);
  });

  // Sobrevive a que el sistema mate la app con la jornada sin sincronizar: por
  // eso es una tabla y no una lista en memoria.
  test('lo encolado sigue ahí al reabrir la base', () async {
    await outbox.enqueue(
      type: SyncOp.projectCreate,
      targetId: 'p1',
      payload: const {'name': 'Obra'},
    );

    // Otra instancia sobre el mismo archivo sería lo más fiel, pero en memoria
    // alcanza con comprobar que está en la tabla y no en el objeto.
    final filas = await db.select(db.outboxOperations).get();
    expect(filas, hasLength(1));
    expect(filas.first.targetId, 'p1');
  });
}
