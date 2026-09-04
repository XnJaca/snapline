import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/sync_client.dart';
import 'package:snapline/api/models/sync_pull_response_dto.dart';
import 'package:snapline/api/models/sync_push_dto.dart';
import 'package:snapline/api/models/sync_push_response_dto.dart';
import 'package:snapline/api/models/sync_result_dto.dart';
import 'package:snapline/api/models/sync_result_dto_status.dart';
import 'package:snapline/api/models/time_entry.dart';
import 'package:snapline/api/models/time_entry_method.dart';
import 'package:snapline/api/models/time_entry_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/time_entry_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// Los dos criterios de `CONFLICT` que SPEC-0004 dejó abiertos: los códigos
/// estaban mapeados en `synchronizer.dart` y nunca se ejercitaban, porque no
/// había forma de producir un conflicto de `time_entry` sin el marcaje.
///
/// La regla 12 en código: unas horas chocadas **se marcan y las mira un
/// humano** — no se sobrescriben, no se descartan, no se reintentan solas.
void main() {
  late AppDatabase db;
  late Outbox outbox;
  late TimeEntryRepository repo;

  const yo = 'membresia-carlos';
  const obra = '019fee39-3f81-725f-8c86-1010b84c9dd4';

  setUp(() {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
    repo = TimeEntryRepository(db, outbox, const Uuid());
  });

  tearDown(() => db.close());

  Future<String> unaEntrada() => repo.clockIn(
    projectId: obra,
    membershipId: yo,
    recordedByMembershipId: yo,
    companyId: 'c1',
  );

  group('marcar nunca falla (regla 9)', () {
    test('sin evidencia alguna: la fila queda y el payload va con lo que hay', () async {
      final id = await unaEntrada();

      final abierta = await repo.watchOpen(yo).first;
      expect(abierta, isNotNull);
      expect(abierta!.id, id);
      expect(abierta.abierta, isTrue);
      expect(abierta.pendiente, isTrue);
      expect(abierta.method, 'SELF');

      final ops = await outbox.pending();
      expect(ops, hasLength(1));
      expect(ops.first.type, SyncOp.timeEntryClockIn);
      final payload = jsonDecode(ops.first.payload) as Map<String, Object?>;
      expect(payload['id'], id);
      expect(payload['recordedOffline'], isTrue);
      // Marcar por uno mismo no manda membershipId: el servidor usa el del token.
      expect(payload.containsKey('membershipId'), isFalse);
      // Lo que el servidor deriva no viaja jamás (ADR-0003).
      expect(payload.containsKey('withinGeofence'), isFalse);
      expect(payload.containsKey('distanceM'), isFalse);
    });

    test('marcar por otro manda quién, y method queda FOREMAN', () async {
      await repo.clockIn(
        projectId: obra,
        membershipId: 'otra-persona',
        recordedByMembershipId: yo,
        recordedByRole: 'FOREMAN',
        companyId: 'c1',
      );

      final abierta = await repo.watchOpen('otra-persona').first;
      expect(abierta!.method, 'FOREMAN');
      expect(abierta.recordedByMembershipId, yo);

      final payload =
          jsonDecode((await outbox.pending()).first.payload) as Map<String, Object?>;
      expect(payload['membershipId'], 'otra-persona');
    });
  });

  group('los dos criterios de CONFLICT de SPEC-0004', () {
    test('TIME_ENTRY_ALREADY_OPEN deja la fila en CONFLICT, visible y sin reintento', () async {
      final id = await unaEntrada();

      // La UI observa; no vuelve a consultar.
      final estados = <SyncStatus>[];
      final sub = repo
          .watchOpen(yo)
          .listen((e) => estados.add(e?.syncStatus ?? SyncStatus.synced));
      await pumpEventQueue();

      final api = _SyncClientQueRechaza({id: 'TIME_ENTRY_ALREADY_OPEN'});
      final sincronizador = Synchronizer(db, api, outbox);
      await sincronizador.push();
      await pumpEventQueue();

      // 1. La fila quedó en CONFLICT y la pantalla se enteró sin reconstruirse.
      expect(estados.last, SyncStatus.conflict);

      // 2. La operación sigue en la cola —se ve, con su motivo— pero el próximo
      //    push no la reenvía: la resuelve un humano, no un reintento.
      final ops = await outbox.pending();
      expect(ops, hasLength(1));
      expect(ops.first.lastError, 'TIME_ENTRY_ALREADY_OPEN');

      await sincronizador.push();
      expect(api.pushes, hasLength(1), reason: 'el segundo push no manda nada');

      // 3. Y también aparece en la lista de conflictos que verá quien resuelva.
      final conflictos = await repo.watchConflicts().first;
      expect(conflictos.single.id, id);
      await sub.cancel();
    });

    test('TIME_ENTRY_ALREADY_CLOSED al cerrar deja el mismo rastro', () async {
      final id = await unaEntrada();
      await repo.clockOut(id);

      final api = _SyncClientQueRechaza(
        {id: 'TIME_ENTRY_ALREADY_CLOSED'},
        soloTipo: SyncOp.timeEntryClockOut,
      );
      await Synchronizer(db, api, outbox).push();

      final conflictos = await repo.watchConflicts().first;
      expect(conflictos.single.id, id);
    });
  });

  group('lo que NO es conflicto', () {
    test('cualquier otro código queda reintentable y no marca nada', () async {
      final id = await unaEntrada();

      final api = _SyncClientQueRechaza({id: 'VALIDATION_FAILED'});
      final sincronizador = Synchronizer(db, api, outbox);
      await sincronizador.push();

      final abierta = await repo.watchOpen(yo).first;
      expect(abierta!.enConflicto, isFalse, reason: 'no es un choque de horas');

      // Y el próximo push SÍ la reenvía: es un error transitorio.
      await sincronizador.push();
      expect(api.pushes, hasLength(2));
    });

    test('el pull no pisa una fila en CONFLICT (regla 12)', () async {
      final id = await unaEntrada();
      final api = _SyncClientQueRechaza(
        {id: 'TIME_ENTRY_ALREADY_OPEN'},
        entradaDelServidor: id,
      );
      final sincronizador = Synchronizer(db, api, outbox);
      await sincronizador.push();

      // El servidor manda "su" versión de la misma fila en el pull.
      await sincronizador.pull();

      final conflictos = await repo.watchConflicts().first;
      expect(
        conflictos.single.id,
        id,
        reason: 'última escritura gana aplica a todo, menos a esto',
      );
    });
  });
}

/// Rechaza operaciones puntuales con el código que se le indique; el resto lo
/// aplica. Registra cada push para poder afirmar qué viajó y qué no.
class _SyncClientQueRechaza implements SyncClient {
  _SyncClientQueRechaza(
    this.rechazos, {
    this.soloTipo,
    this.entradaDelServidor,
  });

  /// targetId → código de error.
  final Map<String, String> rechazos;
  final String? soloTipo;
  final String? entradaDelServidor;
  final pushes = <SyncPushDto>[];

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async {
    pushes.add(body);
    return SyncPushResponseDto(
      failed: 0,
      results: [
        for (final op in body.operations)
          if (rechazos.containsKey(op.targetId) &&
              (soloTipo == null || op.type.json == soloTipo))
            SyncResultDto(
              clientId: op.clientId,
              status: SyncResultDtoStatus.failed,
              resourceId: op.targetId,
              code: rechazos[op.targetId],
              message: null,
            )
          else
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
  Future<SyncPullResponseDto> syncPull({String? since}) async {
    return SyncPullResponseDto(
      serverTime: DateTime.utc(2026, 8, 11),
      customers: const [],
      sites: const [],
      projects: const [],
      assignments: const [],
      mediaAssets: const [],
      // La versión "del servidor" de la fila chocada: si el pull la pisara, el
      // conflicto desaparecería en silencio.
      timeEntries: [
        if (entradaDelServidor != null) _entrada(entradaDelServidor!),
      ],
      crews: const [],
      crewMembers: const [],
      projectStatusChanges: const [],
      projectUpdates: const [],
      people: const [],
      deleted: const {},
    );
  }

  static TimeEntry _entrada(String id) => TimeEntry(
    id: id,
    companyId: 'c1',
    projectId: '019fee39-3f81-725f-8c86-1010b84c9dd4',
    membershipId: 'otro',
    recordedByMembershipId: 'otro',
    clockInAt: DateTime.utc(2026, 8, 11, 7),
    clockOutAt: null,
    decisionReason: null,
    breakMinutes: 0,
    clockInLat: null,
    clockInLng: null,
    clockInAccuracyM: null,
    clockInDistanceM: null,
    clockInWithinGeofence: null,
    clockInPhotoId: null,
    clockOutLat: null,
    clockOutLng: null,
    clockOutAccuracyM: null,
    clockOutDistanceM: null,
    clockOutWithinGeofence: null,
    clockOutPhotoId: null,
    method: TimeEntryMethod.self,
    deviceId: null,
    isMockLocation: false,
    recordedOffline: false,
    deviceRecordedAt: DateTime.utc(2026, 8, 11, 7),
    serverReceivedAt: DateTime.utc(2026, 8, 11, 7),
    status: TimeEntryStatus.pending,
    approvedByMembershipId: null,
    approvedAt: null,
    flags: const [],
    createdAt: DateTime.utc(2026, 8, 11, 7),
    updatedAt: DateTime.utc(2026, 8, 11, 7),
    deletedAt: null,
  );
}
