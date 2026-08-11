import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/core/location/device_location.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/data/local/app_database.dart';

import 'support/fakes.dart';

/// La pantalla del foreman: quién marcó y quién no, y marcar por otro.
///
/// El criterio del spec que esto protege: la lista es **de la obra, no de la
/// cuadrilla**, y marcar por alguien fuera de la lista es posible — la bandera
/// la pone el servidor, nunca un bloqueo del móvil.
class _GpsFijo implements DeviceLocation {
  const _GpsFijo();
  @override
  Future<LocationResult> current() async =>
      const LocationResult.ok(39.0042, -77.0261);
}

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// La obra de hoy con Carlos asignado directo, y la gente conocida.
  Future<void> obraConGente() async {
    await seedProject(db, id: 'p1', name: 'Techo Martinez', customerName: 'Martínez');
    await db.into(db.projectAssignments).insertOnConflictUpdate(
      ProjectAssignmentsCompanion.insert(
        id: 'a1',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        projectId: 'p1',
        membershipId: const Value('m-carlos'),
        workDate: DateTime.now(),
      ),
    );
    // María también está asignada: es quien mira la pantalla.
    await db.into(db.projectAssignments).insertOnConflictUpdate(
      ProjectAssignmentsCompanion.insert(
        id: 'a2',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        projectId: 'p1',
        membershipId: const Value('m1'),
        workDate: DateTime.now(),
      ),
    );
    for (final (id, nombre, rol) in [
      ('m-carlos', 'Carlos Ramírez', 'WORKER'),
      ('m1', 'María López', 'FOREMAN'),
      ('m-w2', 'Pedro Solís', 'WORKER'),
    ]) {
      await db.into(db.people).insertOnConflictUpdate(
        PeopleCompanion.insert(membershipId: id, name: nombre, role: rol),
      );
    }
  }

  Widget app() => testApp(
    db: db,
    session: buildSession(role: AuthMembershipDtoRole.foreman),
    lastDestination: AppDestination.crew,
    deviceLocation: const _GpsFijo(),
  );

  testWidgets('la lista es la gente de la obra, con su estado', (tester) async {
    await obraConGente();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Carlos Ramírez'), findsOneWidget);
    expect(find.text('María López'), findsOneWidget);
    // Pedro es conocido pero no está asignado hoy: no aparece en la lista.
    expect(find.text('Pedro Solís'), findsNothing);
    expect(find.textContaining('Sin marcar'), findsWidgets);
    await desmontar(tester);
  });

  testWidgets('marcar por otro deja recordedBy del foreman y method FOREMAN', (tester) async {
    await obraConGente();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // El botón de marcar en la fila de Carlos.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Carlos Ramírez'),
          matching: find.byType(Container),
        ).first,
        matching: find.byIcon(Icons.login),
      ),
    );
    await tester.pumpAndSettle();

    final filas = await db.select(db.timeEntries).get();
    expect(filas, hasLength(1));
    expect(filas.first.membershipId, 'm-carlos');
    expect(filas.first.recordedByMembershipId, 'm1');
    expect(filas.first.method, 'FOREMAN');

    // Y la fila cambia a "adentro" con la salida ofrecida.
    expect(find.textContaining('Adentro desde'), findsOneWidget);

    // El SnackBar dura 4 segundos: dejarlo irse o su timer queda pendiente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await desmontar(tester);
  });

  testWidgets('marcar por alguien fuera de la lista es posible — bandera, no bloqueo', (tester) async {
    await obraConGente();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Otra persona…'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'el sheet abrió');

    // Pedro no está asignado hoy, pero vino a la obra: se marca igual. La
    // bandera RECORDER_NOT_ASSIGNED es asunto del servidor, no de esta pantalla.
    await tester.tap(find.text('Pedro Solís'));
    await tester.pumpAndSettle();

    final filas = await db.select(db.timeEntries).get();
    expect(filas.single.membershipId, 'm-w2');
    expect(filas.single.method, 'FOREMAN');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await desmontar(tester);
  });

  testWidgets('el dueño que marca por otro queda ADMIN también en local', (tester) async {
    await obraConGente();
    await tester.pumpWidget(
      testApp(
        db: db,
        session: buildSession(role: AuthMembershipDtoRole.owner),
        lastDestination: AppDestination.crew,
        deviceLocation: const _GpsFijo(),
      ),
    );
    await tester.pumpAndSettle();
    // El OWNER no tiene el eje Cuadrilla en su barra — verificado por
    // navigation_test — así que esto se prueba por el repositorio directo.
    final repo = testTimeEntryRepository(db);
    await repo.clockIn(
      projectId: 'p1',
      membershipId: 'm-carlos',
      recordedByMembershipId: 'm-owner',
      recordedByRole: 'OWNER',
      companyId: 'c1',
    );
    final filas = await db.select(db.timeEntries).get();
    expect(filas.single.method, 'ADMIN');
    await desmontar(tester);
  });
}
