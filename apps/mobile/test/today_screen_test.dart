import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/location/device_location.dart';
import 'package:snapline/core/widgets/field_action_button.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/sync/outbox.dart';

import 'support/fakes.dart';

/// La pantalla Hoy: dónde trabajo, marcar entrada, marcar salida.
///
/// El invariante que estos casos protegen es la regla 9: **ninguna rama del
/// marcaje puede terminar sin fila escrita** — el GPS que falla es una bandera,
/// no un bloqueo.
class _GpsFijo implements DeviceLocation {
  const _GpsFijo(this.resultado);
  final LocationResult resultado;

  @override
  Future<LocationResult> current() async => resultado;
}

const _gpsOk = LocationResult.ok(39.0042, -77.0261);
const _gpsSimulado = LocationResult.ok(39.0042, -77.0261, isMocked: true);
const _gpsDenegado = LocationResult.failed(LocationFailure.denied);


/// Drift agenda un `Timer(0)` al cerrar cada stream cuando el árbol se
/// desmonta, y el binding verifica "sin timers pendientes" antes de dejarlo
/// correr. Desmontar adentro del test y bombear una vez lo drena.
Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Con duración explícita: pump() a secas no avanza el reloj falso y los
  // timers de duración cero quedarían pendientes igual.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// Una obra con asignación directa para hoy, como si hubiera bajado del pull.
  Future<void> asignadaHoy(String membershipId, {String id = 'p1'}) async {
    await seedProject(db, id: id, name: 'Techo Martinez', customerName: 'Martínez');
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

  Widget app({LocationResult gps = _gpsOk}) => testApp(
    db: db,
    session: buildSession(role: AuthMembershipDtoRole.worker),
    deviceLocation: _GpsFijo(gps),
  );

  testWidgets('sin asignación, el estado vacío dice a quién pedirle una', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Pedile a tu encargado'),
      findsOneWidget,
      reason: 'no puede decir "sin datos": explica el camino',
    );
    expect(find.byType(FieldActionButton), findsNothing);
    await desmontar(tester);
  });

  testWidgets('marcar entrada escribe la fila, encola y arranca el cronómetro', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Marcar entrada'), findsOneWidget);
    // Ver a dónde ir: la dirección en la tarjeta y el camino a Mapas.
    expect(find.textContaining('412 Ellsworth Dr'), findsOneWidget);
    expect(find.byIcon(Icons.directions_outlined), findsOneWidget);

    await tester.tap(find.byType(FieldActionButton));
    // El cronómetro es un Timer.periodic: pumpAndSettle no "asienta" nunca.
    await tester.pump(const Duration(seconds: 2));

    // La fila existe, el cronómetro corre, el botón cambió.
    final filas = await db.select(db.timeEntries).get();
    expect(filas, hasLength(1));
    expect(filas.first.method, 'SELF');
    expect(find.text('Marcar salida'), findsOneWidget);
    expect(find.textContaining(':'), findsWidgets);

    final ops = await db.select(db.outboxOperations).get();
    expect(ops.where((o) => o.type == SyncOp.timeEntryClockIn), hasLength(1));

    // El cronómetro no es un número suelto: la obra, su dirección y el ánimo
    // siguen en pantalla con la jornada abierta. El lugar emite un frame
    // después de la jornada: un pump más.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Techo Martinez'), findsOneWidget);
    expect(find.textContaining('412 Ellsworth Dr'), findsOneWidget);
    expect(find.textContaining('Arrancó la jornada'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('sin GPS se marca igual, con el aviso — regla 9', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app(gps: _gpsDenegado));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    final filas = await db.select(db.timeEntries).get();
    expect(filas, hasLength(1), reason: 'ninguna rama termina sin fila');
    expect(find.textContaining('sin ubicación'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('el GPS simulado viaja con su bandera — regla 11', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app(gps: _gpsSimulado));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    final ops = await db.select(db.outboxOperations).get();
    final payload = ops
        .firstWhere((o) => o.type == SyncOp.timeEntryClockIn)
        .payload;
    expect(
      payload.contains('"isMockLocation":true'),
      isTrue,
      reason: 'sin esta bandera la geocerca es teatro',
    );
    await desmontar(tester);
  });

  testWidgets('marcar salida cierra la jornada', (tester) async {
    await asignadaHoy('m1');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byType(FieldActionButton));
    await tester.pump(const Duration(seconds: 2));

    final filas = await db.select(db.timeEntries).get();
    expect(filas.single.clockOutAt, isNotNull);
    expect(find.text('Marcar entrada'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('con dos obras hay que elegir antes de poder marcar', (tester) async {
    await asignadaHoy('m1', id: 'p1');
    await asignadaHoy('m1', id: 'p2');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final boton = tester.widget<FieldActionButton>(find.byType(FieldActionButton));
    expect(boton.onPressed, isNull, reason: 'sin obra elegida no hay marcaje');

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    final activo = tester.widget<FieldActionButton>(find.byType(FieldActionButton));
    expect(activo.onPressed, isNotNull);
    await desmontar(tester);
  });

  testWidgets('una jornada en CONFLICT se explica en pantalla', (tester) async {
    await asignadaHoy('m1');
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: 't1',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        syncStatus: const Value(SyncStatus.conflict),
        projectId: 'p1',
        membershipId: 'm1',
        recordedByMembershipId: 'm1',
        clockInAt: DateTime.now().subtract(const Duration(hours: 2)),
        method: 'SELF',
        status: 'PENDING',
      ),
    );

    await tester.pumpWidget(app());
    // Con la jornada abierta el cronómetro no deja "asentar": varios frames a
    // mano para que la sesión y los streams alcancen a emitir.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.textContaining('necesitan revisión'), findsOneWidget);
    expect(
      find.textContaining('No se perdió ni se sobrescribió nada'),
      findsOneWidget,
      reason: 'un estado sin explicación se lee como un error de la app',
    );
    await desmontar(tester);
  });

  testWidgets('nada quemado: la pantalla de un usuario en inglés sale en inglés', (tester) async {
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

    expect(find.text('Clock in'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    await desmontar(tester);
  });
}
