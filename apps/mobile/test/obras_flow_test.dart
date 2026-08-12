import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/location/device_location.dart';
import 'package:snapline/core/media/photo_capture.dart';
import 'package:snapline/core/widgets/field_action_button.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/sync/outbox.dart';

import 'support/fakes.dart';

/// El flujo de SPEC-0009: las obras como lista, la obra como lugar, y el
/// marcaje adentro — con la lógica de SPEC-0008 intacta, regla 9 incluida.
class _GpsFijo implements DeviceLocation {
  const _GpsFijo(this.resultado);
  final LocationResult resultado;
  @override
  Future<LocationResult> current() async => resultado;
}

class _CamaraFija implements PhotoCapture {
  const _CamaraFija(this.ruta);
  final String? ruta;
  @override
  Future<String?> takePhoto() async => ruta;
}

const _gpsOk = LocationResult.ok(39.0042, -77.0261);
const _gpsDenegado = LocationResult.failed(LocationFailure.denied);

Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> asignadaHoy(String membershipId, {String id = 'p1', String nombre = 'Techo Martinez'}) async {
    await seedProject(db, id: id, name: nombre, customerName: 'Martínez');
    await db.into(db.projectAssignments).insertOnConflictUpdate(
      ProjectAssignmentsCompanion.insert(
        id: 'a-$id',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        projectId: id,
        membershipId: Value(membershipId),
        workDate: DateTime.now(),
      ),
    );
  }

  Widget app({LocationResult gps = _gpsOk, PhotoCapture? camara}) => testApp(
    db: db,
    session: buildSession(role: AuthMembershipDtoRole.worker),
    deviceLocation: _GpsFijo(gps),
    photoCapture: camara,
  );

  Future<void> entrarALaObra(WidgetTester tester) async {
    await tester.tap(find.text('Techo Martinez'));
    await tester.pumpAndSettle();
  }

  testWidgets('sin asignación, el estado vacío dice a quién pedirle una', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Pedile a tu encargado'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('el eje lista las obras con dirección y el resumen semanal', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Obras'), findsWidgets);
    expect(find.text('Techo Martinez'), findsOneWidget);
    expect(find.textContaining('412 Ellsworth Dr'), findsOneWidget);
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.byType(FieldActionButton), findsNothing,
        reason: 'la acción vive adentro de la obra, no en el home');
    await desmontar(tester);
  });

  testWidgets('la obra abre en Registro y marcar escribe la fila — regla 9 intacta', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await entrarALaObra(tester);

    expect(find.text('Registro'), findsOneWidget);
    expect(find.text('Detalle'), findsOneWidget);

    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    final filas = await db.select(db.timeEntries).get();
    expect(filas, hasLength(1));
    expect(find.text('Marcar mi salida'), findsOneWidget);
    expect(find.textContaining('Arrancó la jornada'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing,
        reason: 'la abierta vive en el cronómetro, no repetida como pasada');
    await desmontar(tester);
  });

  testWidgets('la obra con la jornada abierta aparece aunque ya no esté asignada hoy — y se puede cerrar', (tester) async {
    await asignadaHoy('m1', id: 'p1', nombre: 'Techo Martinez');
    // La obra de ayer: existe en local pero sin asignación de hoy.
    await seedProject(db, id: 'p2', name: 'Baño González', customerName: 'González');
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: 't-olvidada',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        syncStatus: const Value(SyncStatus.pending),
        projectId: 'p2',
        membershipId: 'm1',
        recordedByMembershipId: 'm1',
        clockInAt: DateTime.now().subtract(const Duration(hours: 20)),
        method: 'SELF',
        status: 'PENDING',
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Baño González'), findsOneWidget,
        reason: 'sin esto no hay ningún camino para marcar la salida');
    expect(find.text('La jornada está abierta acá'), findsOneWidget);

    await tester.tap(find.text('Baño González'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    final fila = await (db.select(db.timeEntries)
          ..where((t) => t.id.equals('t-olvidada')))
        .getSingle();
    expect(fila.clockOutAt, isNotNull);
    await desmontar(tester);
  });

  testWidgets('sin GPS se marca igual — ninguna rama sin fila', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app(gps: _gpsDenegado));
    await tester.pumpAndSettle();
    await entrarALaObra(tester);

    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    expect(await db.select(db.timeEntries).get(), hasLength(1));
    expect(find.textContaining('sin ubicación'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('sin GPS con foto: el marcaje lleva la foto de respaldo', (tester) async {
    await asignadaHoy('m1');
    final foto = File('${Directory.systemTemp.path}/frente-0009.jpg')
      ..writeAsBytesSync([9, 9, 9]);
    addTearDown(() => foto.deleteSync());

    await tester.pumpWidget(app(gps: _gpsDenegado, camara: _CamaraFija(foto.path)));
    await tester.pumpAndSettle();
    await entrarALaObra(tester);
    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    final ops = await db.select(db.outboxOperations).get();
    expect(
      ops.firstWhere((o) => o.type == SyncOp.timeEntryClockIn).payload,
      contains('photoId'),
    );
    expect(ops.where((o) => o.type == SyncOp.mediaRegister), hasLength(1));
    await desmontar(tester);
  });

  testWidgets('una jornada pasada colapsada muestra el total; expandida, el detalle', (tester) async {
    await asignadaHoy('m1');
    final entrada = DateTime.now().subtract(const Duration(days: 1, hours: 8));
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: 't-ayer',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        syncStatus: const Value(SyncStatus.synced),
        projectId: 'p1',
        membershipId: 'm1',
        recordedByMembershipId: 'm1',
        clockInAt: entrada,
        clockOutAt: Value(entrada.add(const Duration(hours: 8))),
        method: 'SELF',
        status: 'APPROVED',
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await entrarALaObra(tester);

    // Colapsada: el total a la derecha.
    expect(find.text('8h 0m'), findsOneWidget);
    expect(find.textContaining('Entrada a las'), findsNothing);

    await tester.tap(find.text('8h 0m'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Entrada a las'), findsOneWidget);
    expect(find.textContaining('Salida a las'), findsOneWidget);
    expect(find.textContaining('Trabajado: 8h 0m'), findsOneWidget);
    expect(find.text('Aprobada'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('con la jornada abierta en OTRA obra, acá no se puede marcar', (tester) async {
    await asignadaHoy('m1', id: 'p1', nombre: 'Techo Martinez');
    await asignadaHoy('m1', id: 'p2', nombre: 'Baño González');
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: 't-abierta',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        syncStatus: const Value(SyncStatus.pending),
        projectId: 'p2',
        membershipId: 'm1',
        recordedByMembershipId: 'm1',
        clockInAt: DateTime.now().subtract(const Duration(hours: 1)),
        method: 'SELF',
        status: 'PENDING',
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await entrarALaObra(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.textContaining('jornada abierta en Baño González'),
      findsOneWidget,
      reason: 'el aviso nombra la obra, no un genérico',
    );
    expect(find.byType(FieldActionButton), findsNothing,
        reason: 'ni entrada —ya hay una— ni salida —es de otro lugar');
    await desmontar(tester);
  });

  testWidgets('el tab Detalle muestra la dirección y el camino a Mapas', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await entrarALaObra(tester);

    await tester.tap(find.text('Detalle'));
    await tester.pumpAndSettle();

    expect(find.textContaining('412 Ellsworth Dr'), findsOneWidget);
    expect(find.text('Abrir en Mapas'), findsOneWidget);
    expect(find.text('En proceso'), findsOneWidget,
        reason: 'el estado de la obra es parte de la ficha');
    expect(find.textContaining('Martínez'), findsNothing,
        reason: 'ningún dato del cliente: la cuadrilla no navega cartera');
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Cuadrilla'),
      ),
      findsNothing,
      reason: 'el WORKER no tiene crews.read: su obra son dos tabs',
    );
    await desmontar(tester);
  });

  testWidgets('el foreman ve el tercer tab: la cuadrilla de esta obra', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(
      testApp(
        db: db,
        session: buildSession(
          name: 'María López',
          role: AuthMembershipDtoRole.foreman,
        ),
        deviceLocation: const _GpsFijo(_gpsOk),
      ),
    );
    await tester.pumpAndSettle();
    await entrarALaObra(tester);

    // Acotado al TabBar: el eje de abajo también se llama Cuadrilla.
    final tabCuadrilla = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Cuadrilla'),
    );
    expect(tabCuadrilla, findsOneWidget);
    await tester.tap(tabCuadrilla);
    await tester.pumpAndSettle();

    expect(find.text('Otra persona…'), findsOneWidget,
        reason: 'marcar por alguien fuera de la lista vive acá también');
    await desmontar(tester);
  });

  testWidgets('nada quemado: en inglés el eje es Jobs y se marca en inglés', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(
      testApp(
        db: db,
        session: buildSession(
          role: AuthMembershipDtoRole.worker,
          locale: AuthUserDtoLocale.en,
        ),
        deviceLocation: const _GpsFijo(_gpsOk),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsWidgets);
    await tester.tap(find.text('Techo Martinez'));
    await tester.pumpAndSettle();
    expect(find.text('Clock in'), findsOneWidget);
    expect(find.text('Time log'), findsOneWidget);
    await desmontar(tester);
  });
}
