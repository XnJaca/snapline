import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/progress_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// El hilo de Avance: cuatro fuentes locales mezcladas en un solo orden.
///
/// Todo se arma en una consulta con `UNION ALL`, así que estos tests son lo
/// único que la cubre: un `ORDER BY` mal puesto no lo caza el analizador.
void main() {
  late AppDatabase db;
  late ProgressRepository repo;

  const projectId = 'p1';

  setUp(() async {
    db = testDatabase();
    repo = ProgressRepository(db, Outbox(db, const Uuid()), const Uuid());
  });

  tearDown(() => db.close());

  Future<void> hito({
    required String id,
    String? from,
    required String to,
    String? autor,
    required DateTime cuando,
  }) => db.into(db.projectStatusChanges).insert(
        ProjectStatusChangesCompanion.insert(
          id: id,
          companyId: 'co',
          updatedAt: cuando,
          projectId: projectId,
          fromStatus: Value(from),
          toStatus: to,
          changedByMembershipId: Value(autor),
          deviceRecordedAt: cuando,
          serverReceivedAt: cuando,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

  Future<void> nota({
    required String id,
    required String body,
    String visibility = 'INTERNAL',
    required DateTime cuando,
    List<String> assetIds = const [],
    SyncStatus estado = SyncStatus.synced,
  }) => db.into(db.projectUpdates).insert(
        ProjectUpdatesCompanion.insert(
          id: id,
          companyId: 'co',
          updatedAt: cuando,
          projectId: projectId,
          authorMembershipId: 'm1',
          body: body,
          visibility: visibility,
          publishedAt: Value(visibility == 'CLIENT' ? cuando : null),
          assetIds: Value(jsonEncode(assetIds)),
          syncStatus: Value(estado),
        ),
      );

  Future<void> foto({
    required String id,
    required DateTime cuando,
    List<String> tags = const [],
  }) =>
      db.into(db.mediaAssets).insert(MediaAssetsCompanion.insert(
            id: id,
            companyId: 'co',
            updatedAt: cuando,
            projectId: projectId,
            kind: 'PHOTO',
            mime: 'image/jpeg',
            visibility: 'INTERNAL',
            uploadStatus: 'READY',
            capturedAt: Value(cuando),
            tags: Value(jsonEncode(tags)),
          ));

  Future<void> jornada({
    required String id,
    required String membershipId,
    required DateTime entrada,
    DateTime? salida,
  }) => db.into(db.timeEntries).insert(TimeEntriesCompanion.insert(
        id: id,
        companyId: 'co',
        updatedAt: entrada,
        projectId: projectId,
        membershipId: membershipId,
        recordedByMembershipId: membershipId,
        clockInAt: entrada,
        clockOutAt: Value(salida),
        method: 'SELF',
        status: 'PENDING',
      ));

  Future<List<EntradaDelHilo>> hilo({int limite = entradasPorPagina}) =>
      repo.watchHilo(projectId, limite: limite).first;

  group('el orden del hilo', () {
    test('mezcla las clases del hilo, lo más reciente arriba', () async {
      await hito(
        id: 'h1', from: 'LEAD', to: 'ESTIMATED', autor: 'm1',
        cuando: DateTime(2026, 8, 1, 9),
      );
      await foto(id: 'f1', cuando: DateTime(2026, 8, 5, 11));
      await jornada(
        id: 't1', membershipId: 'm1',
        entrada: DateTime(2026, 8, 10, 7), salida: DateTime(2026, 8, 10, 15),
      );
      await nota(id: 'n1', body: 'Faltan tejas', cuando: DateTime(2026, 8, 12, 17));

      final entradas = await hilo();

      expect(entradas.map((e) => e.tipo).toList(), [
        TipoDeEntrada.nota,
        TipoDeEntrada.fotos,
        TipoDeEntrada.hito,
      ]);
    });

    test('ordena por cuándo pasó y no por cuándo llegó', () async {
      // Un cambio hecho sin señal hace días se ubica donde ocurrió. Es la razón
      // por la que el hilo mira `device_recorded_at`.
      await hito(
        id: 'viejo', from: 'LEAD', to: 'ESTIMATED', autor: 'm1',
        cuando: DateTime(2026, 8, 1),
      );
      await db.into(db.projectStatusChanges).insert(
            ProjectStatusChangesCompanion.insert(
              id: 'recien-llegado',
              companyId: 'co',
              // Llegó ahora, pero pasó antes.
              updatedAt: DateTime(2026, 8, 30),
              projectId: projectId,
              fromStatus: const Value(null),
              toStatus: 'LEAD',
              changedByMembershipId: const Value('m1'),
              deviceRecordedAt: DateTime(2026, 7, 20),
              serverReceivedAt: DateTime(2026, 8, 30),
              syncStatus: const Value(SyncStatus.synced),
            ),
          );

      final entradas = await hilo();
      expect(entradas.first.id, 'viejo');
      expect(entradas.last.id, 'recien-llegado');
    });

    test('corta en el límite, y el corte lo hace la base', () async {
      for (var i = 0; i < 8; i++) {
        await nota(id: 'n$i', body: 'nota $i', cuando: DateTime(2026, 8, i + 1));
      }
      expect(await hilo(limite: 3), hasLength(3));
    });
  });

  group('agrupado por día', () {
    test('las fotos del mismo día son una sola entrada', () async {
      // Cuarenta fotos de un techo son un día de trabajo, no cuarenta eventos.
      await foto(id: 'f1', cuando: DateTime(2026, 8, 10, 9));
      await foto(id: 'f2', cuando: DateTime(2026, 8, 10, 14));
      await foto(id: 'f3', cuando: DateTime(2026, 8, 11, 9));

      final fotos = (await hilo()).where((e) => e.tipo == TipoDeEntrada.fotos);
      expect(fotos, hasLength(2));
      expect(fotos.first.cuantasFotos, 1);
      expect(fotos.last.cuantasFotos, 2);
    });

    test('el mismo día se parte por etiqueta', () async {
      // Un antes y un durante del mismo día son dos momentos de la obra, no
      // "3 fotos". Es la distinción que hace legible el hilo.
      await foto(id: 'f1', cuando: DateTime(2026, 8, 10, 9), tags: ['BEFORE']);
      await foto(id: 'f2', cuando: DateTime(2026, 8, 10, 14), tags: ['DURING']);
      await foto(id: 'f3', cuando: DateTime(2026, 8, 10, 15), tags: ['DURING']);

      final fotos = (await hilo()).where((e) => e.tipo == TipoDeEntrada.fotos);
      expect(fotos, hasLength(2));
      expect(fotos.map((e) => e.etiqueta), containsAll(['BEFORE', 'DURING']));
      expect(fotos.firstWhere((e) => e.etiqueta == 'DURING').cuantasFotos, 2);
    });

    test('una foto con varias etiquetas cuenta una sola vez', () async {
      // Gana la que más dice de la obra: un antes no se pierde detrás de un
      // detalle, y la foto no aparece en dos filas.
      await foto(
        id: 'f1', cuando: DateTime(2026, 8, 10, 9), tags: ['DETAIL', 'BEFORE'],
      );

      final fotos = (await hilo()).where((e) => e.tipo == TipoDeEntrada.fotos);
      expect(fotos, hasLength(1));
      expect(fotos.single.etiqueta, 'BEFORE');
    });

    test('las fotos sin etiqueta siguen agrupadas por día', () async {
      await foto(id: 'f1', cuando: DateTime(2026, 8, 10, 9));
      await foto(id: 'f2', cuando: DateTime(2026, 8, 10, 14));

      final fila = (await hilo()).firstWhere((e) => e.tipo == TipoDeEntrada.fotos);
      expect(fila.etiqueta, isEmpty);
      expect(fila.cuantasFotos, 2);
    });

    test('la fila de fotos trae hasta cuatro para la tira', () async {
      for (var i = 0; i < 9; i++) {
        await foto(id: 'f$i', cuando: DateTime(2026, 8, 10, 9, i));
      }
      final fila = (await hilo()).firstWhere((e) => e.tipo == TipoDeEntrada.fotos);
      expect(fila.cuantasFotos, 9);
      expect(fila.assetIds, hasLength(4));
    });

    test('las del marcaje no entran: son evidencia, no material de la obra', () async {
      await foto(id: 'material', cuando: DateTime(2026, 8, 10, 9));
      await foto(id: 'fichaje', cuando: DateTime(2026, 8, 10, 10));
      await jornada(
        id: 't1', membershipId: 'm1',
        entrada: DateTime(2026, 8, 10, 7), salida: DateTime(2026, 8, 10, 15),
      );
      await (db.update(db.timeEntries)..where((t) => t.id.equals('t1')))
          .write(const TimeEntriesCompanion(clockInPhotoId: Value('fichaje')));

      final fila = (await hilo()).firstWhere((e) => e.tipo == TipoDeEntrada.fotos);
      expect(fila.cuantasFotos, 1);
      expect(fila.assetIds, ['material']);
    });

    test('las jornadas no entran: el avance cuenta la obra, no los fichajes',
        () async {
      // Cinco días trabajados y dos fotos daban cinco filas de fichaje y dos de
      // obra. Las horas tienen su propio tab.
      await jornada(
        id: 't1', membershipId: 'm1',
        entrada: DateTime(2026, 8, 10, 7), salida: DateTime(2026, 8, 10, 15),
      );
      await foto(id: 'f1', cuando: DateTime(2026, 8, 10, 9));

      final entradas = await hilo();
      expect(entradas, hasLength(1));
      expect(entradas.single.tipo, TipoDeEntrada.fotos);
    });
  });

  group('el ancla del hilo', () {
    test('una obra anterior al historial ancla en su creación, sin estado',
        () async {
      // De una obra que ya existía no se sabe con qué estado nació: la fila
      // dice cuándo empezó y nada más. Afirmar el estado de hoy en la fecha de
      // creación sería inventar un pasado que nadie atestiguó.
      await seedProject(db, id: projectId, name: 'Techo', customerName: 'M',
          createdAt: DateTime(2026, 7, 1));

      final ancla =
          (await hilo()).firstWhere((e) => e.tipo == TipoDeEntrada.origen);
      expect(ancla.toStatus, null);
      expect(ancla.cuando, DateTime(2026, 7, 1));
    });

    test('una obra nacida en la app sí afirma su estado inicial', () async {
      await seedProject(db, id: projectId, name: 'Techo', customerName: 'M',
          createdAt: DateTime(2026, 7, 1));
      await hito(id: 'nacida', to: 'LEAD', autor: 'm1',
          cuando: DateTime(2026, 7, 1));

      final origen =
          (await hilo()).where((e) => e.tipo == TipoDeEntrada.origen);
      // Uno solo: el hito de `create` es el ancla, no se le suma el sintético.
      expect(origen, hasLength(1));
      expect(origen.single.toStatus, 'LEAD');
    });

    test('sin fecha de creación no se inventa un ancla', () async {
      // Una obra que bajó antes de que el pull trajera `createdAt`. Mejor un
      // hilo sin ancla que uno anclado en una fecha que no es.
      await seedProject(db, id: projectId, name: 'Techo', customerName: 'M');

      expect((await hilo()).where((e) => e.tipo == TipoDeEntrada.origen),
          isEmpty);
    });
  });

  group('lo que todavía está en la bandeja', () {
    Future<void> encolar(String status, DateTime cuando) =>
        db.into(db.outboxOperations).insert(OutboxOperationsCompanion.insert(
              clientId: 'op-$status',
              type: SyncOp.projectUpdate,
              targetId: projectId,
              payload: jsonEncode({'status': status}),
              occurredAt: cuando,
            ));

    test('un cambio encolado toma su origen del hito anterior', () async {
      await hito(
        id: 'h1', from: 'LEAD', to: 'IN_PROGRESS', autor: 'm1',
        cuando: DateTime(2026, 8, 1),
      );
      await encolar('ON_HOLD', DateTime(2026, 8, 20));

      final pendiente = (await hilo()).firstWhere((e) => e.pendiente);
      expect(pendiente.fromStatus, 'IN_PROGRESS');
      expect(pendiente.toStatus, 'ON_HOLD');
    });

    test('dos encolados se encadenan entre sí', () async {
      await hito(
        id: 'h1', from: null, to: 'SCHEDULED', autor: 'm1',
        cuando: DateTime(2026, 8, 1),
      );
      await encolar('IN_PROGRESS', DateTime(2026, 8, 20));
      await encolar('ON_HOLD', DateTime(2026, 8, 21));

      final pendientes = (await hilo()).where((e) => e.pendiente).toList();
      expect(pendientes, hasLength(2));
      // Vienen del más reciente al más viejo.
      expect(pendientes.first.fromStatus, 'IN_PROGRESS');
      expect(pendientes.first.toStatus, 'ON_HOLD');
      expect(pendientes.last.fromStatus, 'SCHEDULED');
      expect(pendientes.last.toStatus, 'IN_PROGRESS');
    });

    test('editar la ficha sin cambiar el estado no aparece como hito', () async {
      // Por `project.update` viaja también la corrección de la obra. Sin este
      // filtro, renombrar una obra sin señal inventaba un hito en el hilo.
      await db.into(db.outboxOperations).insert(
            OutboxOperationsCompanion.insert(
              clientId: 'op-nombre',
              type: SyncOp.projectUpdate,
              targetId: projectId,
              payload: jsonEncode({'name': 'Otro nombre'}),
              occurredAt: DateTime(2026, 8, 20),
            ),
          );

      expect(await hilo(), isEmpty);
    });

    test('una nota sin sincronizar se ve marcada', () async {
      await nota(
        id: 'n1', body: 'Sin señal', cuando: DateTime(2026, 8, 20),
        estado: SyncStatus.pending,
      );
      final entrada = (await hilo()).single;
      expect(entrada.pendiente, isTrue);
      expect(entrada.body, 'Sin señal');
    });
  });

  group('escribir una nota', () {
    test('queda visible al instante y encolada', () async {
      final id = await repo.escribirNota(
        projectId: projectId,
        body: 'Terminamos el lado sur',
        visibility: 'INTERNAL',
        authorMembershipId: 'm1',
        companyId: 'co',
      );

      final entrada = (await hilo()).single;
      expect(entrada.id, id);
      expect(entrada.pendiente, isTrue);
      expect(entrada.visibility, 'INTERNAL');

      final encoladas = await db.select(db.outboxOperations).get();
      expect(encoladas.single.type, SyncOp.projectUpdateCreate);
      expect(encoladas.single.targetId, id);
    });

    test('una nota para el cliente nace publicada y con sus fotos', () async {
      await repo.escribirNota(
        projectId: projectId,
        body: 'Con fotos',
        visibility: 'CLIENT',
        authorMembershipId: 'm1',
        companyId: 'co',
        assetIds: ['a1', 'a2'],
      );

      final entrada = (await hilo()).single;
      expect(entrada.visibility, 'CLIENT');
      expect(entrada.assetIds, ['a1', 'a2']);

      final payload = jsonDecode(
          (await db.select(db.outboxOperations).get()).single.payload);
      expect(payload['assetIds'], ['a1', 'a2']);
      expect(payload['projectId'], projectId);
    });
  });

  group('el conteo de movimientos', () {
    Future<int> movimientos() async =>
        (await repo.watchResumen(projectId).first).cuantosMovimientos;

    test('cuenta lo mismo que el hilo abre', () async {
      await seedProject(db, id: projectId, name: 'Techo', customerName: 'M',
          createdAt: DateTime(2026, 8, 1));
      await nota(id: 'n1', body: 'Una', cuando: DateTime(2026, 8, 10));
      await foto(id: 'f1', cuando: DateTime(2026, 8, 11));

      expect(await movimientos(), (await hilo()).length);
    });

    test('un cambio de estado sin señal también cuenta', () async {
      // El hilo lo pinta leyendo la bandeja. Si el conteo no lo mira, la tab
      // promete «2 movimientos» y el hilo abre con tres.
      await seedProject(db, id: projectId, name: 'Techo', customerName: 'M',
          createdAt: DateTime(2026, 8, 1));
      await nota(id: 'n1', body: 'Una', cuando: DateTime(2026, 8, 10));
      await db.into(db.outboxOperations).insert(
            OutboxOperationsCompanion.insert(
              clientId: 'op1',
              type: SyncOp.projectUpdate,
              targetId: projectId,
              payload: jsonEncode({'status': 'COMPLETED'}),
              occurredAt: DateTime(2026, 8, 12),
            ),
          );

      expect(await movimientos(), (await hilo()).length);
    });

    test('editar la ficha sin tocar el estado no suma', () async {
      // Por `project.update` viaja también la edición de la ficha, que no es un
      // hito y el hilo no la muestra.
      await seedProject(db, id: projectId, name: 'Techo', customerName: 'M',
          createdAt: DateTime(2026, 8, 1));
      await db.into(db.outboxOperations).insert(
            OutboxOperationsCompanion.insert(
              clientId: 'op1',
              type: SyncOp.projectUpdate,
              targetId: projectId,
              payload: jsonEncode({'name': 'Otro nombre'}),
              occurredAt: DateTime(2026, 8, 12),
            ),
          );

      expect(await movimientos(), (await hilo()).length);
      expect(await movimientos(), 1);
    });
  });

}
