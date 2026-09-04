import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/sync_client.dart';
import 'package:snapline/api/models/sync_pull_response_dto.dart';
import 'package:snapline/api/models/sync_push_dto.dart';
import 'package:snapline/api/models/sync_push_response_dto.dart';
import 'package:snapline/api/models/sync_result_dto.dart';
import 'package:snapline/api/models/sync_result_dto_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/time_entry_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// Aprobar y rechazar desde la obra (SPEC-0011).
///
/// Es la primera escritura de la app que un tercero pudo haber hecho antes: la
/// web o el teléfono de otro. De ahí que una decisión rechazada por el servidor
/// tenga tres desenlaces distintos y no uno solo.
void main() {
  late AppDatabase db;
  late Outbox outbox;
  late TimeEntryRepository repo;

  const maria = 'membresia-maria';
  const obra = '019fee39-3f81-725f-8c86-1010b84c9dd4';

  setUp(() {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
    repo = TimeEntryRepository(db, outbox, const Uuid());
  });

  tearDown(() => db.close());

  /// Una jornada cerrada de María, lista para que alguien decida sobre ella.
  Future<String> unaJornadaCerrada() async {
    final id = await repo.clockIn(
      projectId: obra,
      membershipId: maria,
      recordedByMembershipId: maria,
      companyId: 'c1',
    );
    await repo.clockOut(id);
    // Se limpia la cola del marcaje: lo que se prueba acá es la decisión.
    for (final op in await outbox.pending()) {
      await outbox.remove(op.clientId);
    }
    await db.customUpdate(
      'UPDATE time_entries SET sync_status = ? WHERE id = ?',
      variables: [Variable<int>(SyncStatus.synced.index), Variable<String>(id)],
      updates: {db.timeEntries},
    );
    return id;
  }

  Future<TimeEntrySummary> jornada(String id) async {
    final filas = await repo.watchProjectEntries(obra).first;
    return filas.firstWhere((f) => f.entry.id == id).entry;
  }

  group('decidir sin señal escribe en local y encola', () {
    test('aprobar deja la fila aprobada al instante y la operación en la cola', () async {
      final id = await unaJornadaCerrada();

      await repo.decide(id, approve: true);

      final j = await jornada(id);
      expect(j.aprobada, isTrue, reason: 'la pantalla responde sin esperar red');
      expect(j.pendiente, isTrue);

      final ops = await outbox.pending();
      expect(ops.single.type, SyncOp.timeEntryApprove);
      expect(ops.single.targetId, id);
    });

    test('la operación viaja con el estado que el teléfono tenía a la vista', () async {
      final id = await unaJornadaCerrada();

      await repo.decide(id, approve: false, reason: 'no estaba en la obra');

      final ops = await outbox.pending();
      expect(ops.single.type, SyncOp.timeEntryReject);
      expect(
        ops.single.payload,
        contains('"expectedStatus":"PENDING"'),
        reason: 'sin esto el servidor no puede distinguir corregir de chocar',
      );
      expect(ops.single.payload, contains('no estaba en la obra'));
    });

    test('cambiar de opinión sustituye la decisión, no encola otra', () async {
      final id = await unaJornadaCerrada();

      await repo.decide(id, approve: false, reason: 'me equivoqué');
      await repo.decide(id, approve: true);

      final ops = await outbox.pending();
      expect(
        ops,
        hasLength(1),
        reason: 'dos decisiones en la cola se pisan entre sí en el servidor',
      );
      expect(ops.single.type, SyncOp.timeEntryApprove);
      expect(ops.single.payload, contains('"expectedStatus":"PENDING"'));
    });

    test(
      'rechazar y corregir sin señal deja en el servidor lo que la persona quiso',
      () async {
        // El caso que la pantalla habilita: sobre una rechazada solo se ofrece
        // Aprobar, así que "me equivoqué, corrijo" es el camino normal.
        //
        // Con las dos operaciones encoladas, el servidor aplicaba el rechazo y
        // rechazaba la aprobación por no coincidir con el estado que él mismo
        // acababa de cambiar: la jornada terminaba con la decisión descartada y
        // marcada en conflicto, sin que nadie más hubiera decidido nada.
        final id = await unaJornadaCerrada();

        await repo.decide(id, approve: false, reason: 'me equivoqué');
        await repo.decide(id, approve: true);

        final api = _SyncClientConEstado(id, 'PENDING');
        await Synchronizer(db, api, outbox).push();

        expect(api.estado, 'APPROVED', reason: 'lo último que la persona decidió');
        expect(api.aplicadas, 1, reason: 'una sola decisión viaja');

        final j = await jornada(id);
        expect(j.aprobada, isTrue);
        expect(j.enConflicto, isFalse, reason: 'nadie más decidió nada acá');
        expect(await outbox.pending(), isEmpty);
      },
    );
  });

  test(
    'corregir MIENTRAS el push está en vuelo tampoco pierde la decisión',
    () async {
      // La ventana real: encolar dispara la sincronización sola
      // (`syncEngineProvider`), así que el push ya salió cuando la persona toca
      // el segundo botón. Sustituir en la cola no alcanza —la primera operación
      // ya viajó— y la decisión nueva pediría un estado que el servidor acaba de
      // cambiar.
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: false, reason: 'me equivoqué');

      final api = _SyncClientConEstado(id, 'PENDING');
      final enVuelo = Completer<void>();
      api.esperar = enVuelo.future;

      final push = Synchronizer(db, api, outbox).push();
      await pumpEventQueue();

      // La persona toca Aprobar con el POST sin responder.
      final segunda = repo.decide(id, approve: true);
      await pumpEventQueue();

      enVuelo.complete();
      await push;
      await segunda;

      // La segunda decisión salió recién con el turno libre, así que pudo leer
      // en qué quedó la primera.
      await Synchronizer(db, api, outbox).push();

      expect(api.estado, 'APPROVED', reason: 'lo último que la persona decidió');
      final j = await jornada(id);
      expect(j.aprobada, isTrue);
      expect(j.enConflicto, isFalse, reason: 'nadie más decidió nada acá');
      expect(await outbox.pending(), isEmpty);
    },
  );

  group('lo que el servidor rechaza', () {
    test('DECISION_CONFLICTS marca la fila y no se reintenta (regla 12)', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      final api = _SyncClientQueRechaza({id: 'TIME_ENTRY_DECISION_CONFLICTS'});
      final sincronizador = Synchronizer(db, api, outbox);
      await sincronizador.push();

      final j = await jornada(id);
      expect(j.enConflicto, isTrue);

      final conflictos = await repo.watchConflicts().first;
      expect(conflictos.single.id, id);

      // Sigue en la cola para que se vea, pero no vuelve a viajar.
      await sincronizador.push();
      expect(api.pushes, hasLength(1));
    });

    test('DECISION_MATCHES se descarta en silencio: alguien decidió lo mismo', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      final api = _SyncClientQueRechaza({id: 'TIME_ENTRY_DECISION_MATCHES'});
      await Synchronizer(db, api, outbox).push();

      expect(await outbox.pending(), isEmpty, reason: 'sale de la cola');

      final j = await jornada(id);
      expect(j.enConflicto, isFalse);
      expect(j.lastRejection, isNull, reason: 'no hay nada que contarle a nadie');
    });

    test('PAY_RATE_MISSING revierte el estado y deja el motivo, sin conflicto', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      final api = _SyncClientQueRechaza({id: 'PAY_RATE_MISSING'});
      final sincronizador = Synchronizer(db, api, outbox);
      await sincronizador.push();

      final j = await jornada(id);
      expect(j.sinAprobar, isTrue, reason: 'vuelve al estado que tenía antes');
      expect(j.enConflicto, isFalse, reason: 'falta un dato, no hay dos verdades');
      expect(j.lastRejection, 'PAY_RATE_MISSING');

      // Y no se reintenta: reenviar lo mismo falla igual hasta que carguen la
      // tarifa desde la web.
      expect(await outbox.pending(), isEmpty);
      await sincronizador.push();
      expect(api.pushes, hasLength(1));
    });

    test('la reversión no depende de un pull posterior', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      final api = _SyncClientQueRechaza({id: 'PAY_RATE_MISSING'});
      await Synchronizer(db, api, outbox).push();

      // El rechazo ocurrió antes de escribir, así que `updated_at` no se movió y
      // el pull incremental no vuelve a traer la fila. Si la reversión esperara
      // al servidor, esto mostraría "Aprobada" para siempre.
      final j = await jornada(id);
      expect(j.sinAprobar, isTrue);
    });

    test('CANNOT_APPROVE_OWN_HOURS revierte pero no le avisa a nadie', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      final api = _SyncClientQueRechaza({id: 'CANNOT_APPROVE_OWN_HOURS'});
      await Synchronizer(db, api, outbox).push();

      final j = await jornada(id);
      expect(j.sinAprobar, isTrue);
      expect(
        j.lastRejection,
        isNull,
        reason: 'es un bug de la app, no un problema de quien la usa',
      );
    });

    test('un código desconocido nunca descarta: se reintenta', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      final api = _SyncClientQueRechaza({id: 'ALGO_NUEVO_DEL_SERVIDOR'});
      final sincronizador = Synchronizer(db, api, outbox);
      await sincronizador.push();

      expect(
        await outbox.pending(),
        hasLength(1),
        reason: 'descartar trabajo real en silencio es peor que reintentar de más',
      );
      await sincronizador.push();
      expect(api.pushes, hasLength(2));
    });
  });

  group('una decisión que sí se aplica', () {
    test('limpia su rastro local', () async {
      final id = await unaJornadaCerrada();
      await repo.decide(id, approve: true);

      // Sin rechazos: el servidor la aplica.
      await Synchronizer(db, _SyncClientQueRechaza(const {}), outbox).push();

      final j = await jornada(id);
      expect(j.aprobada, isTrue);
      expect(j.pendiente, isFalse);
      expect(j.lastRejection, isNull);

      // Y `decided_from` quedó limpio: si no, el próximo descarte revertiría a
      // un estado ya viejo.
      final fila = await (db.select(db.timeEntries)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(fila.decidedFrom, isNull);
    });
  });
}

/// Rechaza operaciones puntuales con el código que se le indique; el resto lo
/// aplica. Registra cada push para poder afirmar qué viajó y qué no.
class _SyncClientQueRechaza implements SyncClient {
  _SyncClientQueRechaza(this.rechazos);

  /// targetId → código de error.
  final Map<String, String> rechazos;
  final pushes = <SyncPushDto>[];

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async {
    pushes.add(body);
    return SyncPushResponseDto(
      failed: 0,
      results: [
        for (final op in body.operations)
          if (rechazos.containsKey(op.targetId))
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
  Future<SyncPullResponseDto> syncPull({String? since}) async =>
      SyncPullResponseDto(
        serverTime: DateTime.now(),
        customers: const [],
        sites: const [],
        projects: const [],
        assignments: const [],
        mediaAssets: const [],
        timeEntries: const [],
        crews: const [],
        crewMembers: const [],
        projectStatusChanges: const [],
        projectUpdates: const [],
        people: const [],
        deleted: const {},
      );
}

/// Modela el estado de una jornada en el servidor y compara `expectedStatus`
/// como lo hace `assertDecidable`.
///
/// El fake de arriba responde por `targetId` fijo, así que no puede ver el
/// efecto de una operación sobre la siguiente **del mismo lote** — que es
/// exactamente donde vivía el bug de las dos decisiones encoladas.
class _SyncClientConEstado implements SyncClient {
  _SyncClientConEstado(this.entryId, this.estado);

  final String entryId;
  String estado;
  int aplicadas = 0;

  /// Retiene la respuesta, para poder decidir con el POST sin contestar.
  Future<void>? esperar;

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async {
    if (esperar != null) {
      final espera = esperar;
      esperar = null;
      await espera;
    }
    final results = <SyncResultDto>[];
    for (final op in body.operations) {
      final destino =
          op.type.json == SyncOp.timeEntryApprove ? 'APPROVED' : 'REJECTED';
      final expected = op.payload['expectedStatus'] as String?;

      if (op.targetId != entryId) {
        results.add(_ok(op.clientId, op.targetId));
        continue;
      }
      if (estado == destino) {
        results.add(_falla(op.clientId, op.targetId, 'TIME_ENTRY_DECISION_MATCHES'));
      } else if (expected != null && expected != estado) {
        results.add(
          _falla(op.clientId, op.targetId, 'TIME_ENTRY_DECISION_CONFLICTS'),
        );
      } else {
        estado = destino;
        aplicadas++;
        results.add(_ok(op.clientId, op.targetId));
      }
    }
    return SyncPushResponseDto(failed: 0, results: results);
  }

  static SyncResultDto _ok(String clientId, String resourceId) => SyncResultDto(
        clientId: clientId,
        status: SyncResultDtoStatus.applied,
        resourceId: resourceId,
        code: null,
        message: null,
      );

  static SyncResultDto _falla(String clientId, String resourceId, String code) =>
      SyncResultDto(
        clientId: clientId,
        status: SyncResultDtoStatus.failed,
        resourceId: resourceId,
        code: code,
        message: null,
      );

  @override
  Future<SyncPullResponseDto> syncPull({String? since}) async =>
      SyncPullResponseDto(
        serverTime: DateTime.now(),
        customers: const [],
        sites: const [],
        projects: const [],
        assignments: const [],
        mediaAssets: const [],
        timeEntries: const [],
        crews: const [],
        crewMembers: const [],
        projectStatusChanges: const [],
        projectUpdates: const [],
        people: const [],
        deleted: const {},
      );
}
