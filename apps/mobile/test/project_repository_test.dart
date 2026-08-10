import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/project_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/project_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// El alta, la corrección y el cambio de estado de una obra sin señal.
void main() {
  late AppDatabase db;
  late Outbox outbox;
  late ProjectRepository repo;

  setUp(() async {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
    repo = ProjectRepository(db, outbox, const Uuid());

    await seedCustomer(
      db,
      id: 'c1',
      displayName: 'Ana Martínez',
      siteLine1: '412 Ellsworth Dr',
    );
  });

  tearDown(() => db.close());

  ProjectInput input({
    String name = 'Techo Martínez',
    ProjectStatus status = ProjectStatus.inProgress,
  }) => ProjectInput(
    customerId: 'c1',
    siteId: 's-c1',
    name: name,
    status: status,
  );

  group('alta de obra', () {
    test('queda visible al instante y marcada como pendiente', () async {
      final id = await repo.create(input());

      final lista = await repo.watchInProgress().first;
      expect(lista, hasLength(1));
      expect(lista.first.id, id);
      expect(lista.first.name, 'Techo Martínez');
      expect(lista.first.customerName, 'Ana Martínez');
      expect(lista.first.pending, isTrue);
    });

    test('el id del dispositivo es el que va al servidor', () async {
      final id = await repo.create(input());

      final op = (await outbox.pending()).single;
      expect(op.type, SyncOp.projectCreate);
      expect(op.targetId, id);
    });

    test('nace con la visibilidad en etapas', () async {
      final id = await repo.create(input());

      final detalle = await repo.watchDetail(id).first;
      // Pasar a `avance` es acción explícita, no un default de formulario.
      expect(detalle!.clientVisibilityMode, 'STAGES');
      // Y no viaja en el payload: lo pone el servidor con su propio default.
      final payload =
          jsonDecode((await outbox.pending()).single.payload)
              as Map<String, Object?>;
      expect(payload.containsKey('clientVisibilityMode'), isFalse);
    });

    test('la fila local nace PENDING', () async {
      final id = await repo.create(input());

      final fila = await (db.select(
        db.projects,
      )..where((p) => p.id.equals(id))).getSingle();
      expect(fila.syncStatus, SyncStatus.pending);
    });

    test('las fechas viajan como date y no como date-time', () async {
      await repo.create(
        ProjectInput(
          customerId: 'c1',
          siteId: 's-c1',
          name: 'Con fechas',
          status: ProjectStatus.scheduled,
          startDate: DateTime(2026, 8, 3),
          targetEndDate: DateTime(2026, 9, 15),
        ),
      );

      final payload =
          jsonDecode((await outbox.pending()).single.payload)
              as Map<String, Object?>;
      // El contrato las declara `date`: mandar un instante ISO completo lo
      // rechaza la validación del servidor.
      expect(payload['startDate'], '2026-08-03');
      expect(payload['targetEndDate'], '2026-09-15');
    });
  });

  group('la cartera', () {
    test('muestra solo lo que está en proceso', () async {
      await repo.create(input(name: 'En obra'));
      await repo.create(input(name: 'Agendada', status: ProjectStatus.scheduled));

      final cartera = await repo.watchInProgress().first;
      expect(cartera.map((p) => p.name), ['En obra']);

      // La agendada existe, pero vive detrás de "ver todas".
      final todas = await repo.watchAll().first;
      expect(todas.map((p) => p.name), containsAll(['En obra', 'Agendada']));
    });

    test('busca por nombre de obra', () async {
      await repo.create(input(name: 'Techo Martínez'));
      await repo.create(input(name: 'Baño Smith'));

      final resultado = await repo.watchInProgress(query: 'techo').first;
      expect(resultado.map((p) => p.name), ['Techo Martínez']);
    });

    test('busca por nombre de cliente', () async {
      await seedCustomer(db, id: 'c2', displayName: 'Bob Smith', siteLine1: 'Otra');
      await repo.create(input(name: 'Obra uno'));
      await repo.create(
        const ProjectInput(
          customerId: 'c2',
          siteId: 's-c2',
          name: 'Obra dos',
          status: ProjectStatus.inProgress,
        ),
      );

      // Quien busca se acuerda de uno de los dos, y no del mismo siempre.
      final resultado = await repo.watchInProgress(query: 'smith').first;
      expect(resultado.map((p) => p.name), ['Obra dos']);
    });
  });

  group('corrección de obra', () {
    test('se ve al instante y encola una sola operación', () async {
      final id = await repo.create(input(name: 'Antes'));
      await outbox.remove((await outbox.pending()).single.clientId);

      await repo.update(id, input(name: 'Después'));

      final detalle = await repo.watchDetail(id).first;
      expect(detalle!.name, 'Después');
      expect(await outbox.pending(), hasLength(1));
    });

    test('la corrección no manda el cliente ni la propiedad', () async {
      final id = await repo.create(input());
      await outbox.remove((await outbox.pending()).single.clientId);

      await repo.update(id, input(name: 'Corregida'));

      // Se fijan al crear (ficha de `proyecto`), y `UpdateProjectDto` no los
      // declara: mandarlos los descartaba `whitelist` sin decir nada, así que la
      // app mostraba guardado algo que no se guardaba.
      final payload =
          jsonDecode((await outbox.pending()).single.payload)
              as Map<String, Object?>;
      expect(payload.containsKey('customerId'), isFalse);
      expect(payload.containsKey('siteId'), isFalse);
    });

    test('la corrección no manda el estado', () async {
      final id = await repo.create(input());
      await outbox.remove((await outbox.pending()).single.clientId);

      await repo.update(id, input(name: 'Corregida'));

      // El estado va por `changeStatus`: el servidor puede descartarlo y aplicar
      // el resto, y mezclarlos dejaría al dispositivo sin saber qué se aplicó.
      final payload =
          jsonDecode((await outbox.pending()).single.payload)
              as Map<String, Object?>;
      expect(payload.containsKey('status'), isFalse);
      expect(payload['name'], 'Corregida');
    });
  });

  group('cambio de estado', () {
    test('se aplica local y encola solo el estado', () async {
      final id = await repo.create(input(status: ProjectStatus.scheduled));
      await outbox.remove((await outbox.pending()).single.clientId);

      await repo.changeStatus(id, ProjectStatus.inProgress);

      final detalle = await repo.watchDetail(id).first;
      expect(detalle!.status, ProjectStatus.inProgress);
      expect(detalle.pending, isTrue);

      final op = (await outbox.pending()).single;
      expect(op.type, SyncOp.projectUpdate);
      expect(jsonDecode(op.payload), {'status': 'IN_PROGRESS'});
    });

    test('cancelar no borra la obra ni la saca de la base', () async {
      final id = await repo.create(input());

      await repo.changeStatus(id, ProjectStatus.cancelled);

      // `CANCELLED` no borra nada: sale de la cartera y se sigue consultando.
      expect(await repo.watchInProgress().first, isEmpty);
      final cancelada = await repo.watchAll(
        status: ProjectStatus.cancelled,
      ).first;
      expect(cancelada.map((p) => p.id), [id]);

      final fila = await (db.select(
        db.projects,
      )..where((p) => p.id.equals(id))).getSingle();
      expect(fila.deletedAt, isNull);
    });
  });

  group('el detalle', () {
    test('trae el cliente y la dirección resueltos', () async {
      final id = await repo.create(input());

      final detalle = await repo.watchDetail(id).first;
      expect(detalle!.customerName, 'Ana Martínez');
      expect(detalle.site, '412 Ellsworth Dr, Silver Spring, MD');
      expect(detalle.customerId, 'c1');
      expect(detalle.siteId, 's-c1');
    });

    test('una obra que no está devuelve null', () async {
      expect(await repo.watchDetail('no-existe').first, isNull);
    });

    test('una obra borrada no se devuelve', () async {
      final id = await repo.create(input());
      await db.customStatement(
        'UPDATE projects SET deleted_at = ? WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch ~/ 1000, id],
      );

      expect(await repo.watchDetail(id).first, isNull);
    });
  });

  // El caso crítico del spec: el trío, sin señal, en orden.
  test('cliente, propiedad y obra sin señal salen en ese orden', () async {
    final momento = DateTime(2026, 8, 10, 9);
    await outbox.enqueue(
      type: SyncOp.customerCreate,
      targetId: 'c-nuevo',
      payload: const {'displayName': 'Nuevo'},
      occurredAt: momento,
    );
    await outbox.enqueue(
      type: SyncOp.siteCreate,
      targetId: 's-nuevo',
      payload: const {'customerId': 'c-nuevo'},
      occurredAt: momento,
    );
    await repo.create(
      const ProjectInput(
        customerId: 'c-nuevo',
        siteId: 's-nuevo',
        name: 'Obra del trío',
        status: ProjectStatus.inProgress,
      ),
      occurredAt: momento,
    );

    expect(
      (await outbox.pending()).map((o) => o.type),
      [SyncOp.customerCreate, SyncOp.siteCreate, SyncOp.projectCreate],
    );
  });
}
