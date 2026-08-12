import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/core/location/device_location.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';

import 'support/fakes.dart';

/// El eje Cuadrilla de SPEC-0009: lista de cuadrillas, y adentro los tabs
/// Personas y Horas. Con una sola cuadrilla —el caso normal— se entra directo.
class _GpsFijo implements DeviceLocation {
  @override
  Future<LocationResult> current() async =>
      const LocationResult.ok(39.0042, -77.0261);
}

Future<void> desmontar(WidgetTester tester) async {
  // El SnackBar de "quedó marcada" dura 4s: hay que drenarlo antes de irse.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> cuadrilla(
    String id,
    String nombre, {
    List<(String, String)> gente = const [],
  }) async {
    final ahora = DateTime.now();
    await db.into(db.crews).insertOnConflictUpdate(
      CrewsCompanion.insert(
        id: id,
        companyId: 'c1',
        updatedAt: ahora,
        name: nombre,
        foremanMembershipId: const Value('m1'),
        syncStatus: const Value(SyncStatus.synced),
      ),
    );
    for (final (membershipId, nombrePersona) in gente) {
      await db.into(db.crewMembers).insertOnConflictUpdate(
        CrewMembersCompanion.insert(
          id: 'cm-$id-$membershipId',
          companyId: 'c1',
          updatedAt: ahora,
          crewId: id,
          membershipId: membershipId,
          fromDate: ahora.subtract(const Duration(days: 90)),
          syncStatus: const Value(SyncStatus.synced),
        ),
      );
      await db.into(db.people).insertOnConflictUpdate(
        PeopleCompanion.insert(
          membershipId: membershipId,
          name: nombrePersona,
          role: 'WORKER',
        ),
      );
    }
  }

  Future<void> asignadaHoy(String membershipId, {String id = 'p1'}) async {
    await seedProject(db, id: id, name: 'Techo Martinez', customerName: 'Martínez');
    await db.into(db.projectAssignments).insertOnConflictUpdate(
      ProjectAssignmentsCompanion.insert(
        id: 'a-$id-$membershipId',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        projectId: id,
        membershipId: Value(membershipId),
        workDate: DateTime.now(),
      ),
    );
  }

  Widget app() => testApp(
    db: db,
    session: buildSession(
      name: 'María López',
      role: AuthMembershipDtoRole.foreman,
    ),
    lastDestination: AppDestination.crew,
    deviceLocation: _GpsFijo(),
  );

  testWidgets('el eje lista la cuadrilla — aunque sea una sola — y el toque la abre', (tester) async {
    await cuadrilla('cr1', 'Cuadrilla A', gente: [('m1', 'María López'), ('m2', 'Carlos Ruiz')]);
    await asignadaHoy('m1');
    await asignadaHoy('m2');

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Tus cuadrillas'), findsOneWidget,
        reason: 'siempre la lista: entrar directo caía en una pantalla no pedida');
    expect(find.text('Cuadrilla A'), findsOneWidget);
    expect(find.text('Personas'), findsNothing);

    await tester.tap(find.text('Cuadrilla A'));
    await tester.pumpAndSettle();

    expect(find.text('Personas'), findsOneWidget);
    expect(find.text('Horas'), findsOneWidget);
    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('Sin marcar hoy'), findsWidgets);
    await desmontar(tester);
  });

  testWidgets('marcar por otro escribe la fila con quién la marcó', (tester) async {
    await cuadrilla('cr1', 'Cuadrilla A', gente: [('m1', 'María López'), ('m2', 'Carlos Ruiz')]);
    await asignadaHoy('m1');
    await asignadaHoy('m2');

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cuadrilla A'));
    await tester.pumpAndSettle();

    // La fila de Carlos: su nombre y su botón viven en la misma Column.
    final cardCarlos = find.ancestor(
      of: find.text('Carlos Ruiz'),
      matching: find.byType(Column),
    ).first;
    await tester.tap(
      find.descendant(of: cardCarlos, matching: find.text('Marcar entrada')),
    );
    await tester.pump(const Duration(seconds: 2));

    final filas = await db.select(db.timeEntries).get();
    expect(filas, hasLength(1));
    expect(filas.single.membershipId, 'm2');
    expect(filas.single.recordedByMembershipId, 'm1');
    expect(filas.single.method, 'FOREMAN');

    // La card lo dice con palabras: ya marcó, y lo único que queda es salida.
    expect(
      find.descendant(
        of: cardCarlos,
        matching: find.textContaining('Marcó entrada hoy a las'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardCarlos, matching: find.text('Marcar salida')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardCarlos, matching: find.text('Marcar entrada')),
      findsNothing,
      reason: 'adentro no existe la segunda entrada como opción',
    );
    await desmontar(tester);
  });

  testWidgets('el tab Horas suma la semana por persona', (tester) async {
    await cuadrilla('cr1', 'Cuadrilla A', gente: [('m1', 'María López'), ('m2', 'Carlos Ruiz')]);
    await asignadaHoy('m1');
    final entrada = DateTime.now().subtract(const Duration(days: 1, hours: 9));
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: 't-carlos',
        companyId: 'c1',
        updatedAt: DateTime.now(),
        syncStatus: const Value(SyncStatus.synced),
        projectId: 'p1',
        membershipId: 'm2',
        recordedByMembershipId: 'm2',
        clockInAt: entrada,
        clockOutAt: Value(entrada.add(const Duration(hours: 8, minutes: 30))),
        breakMinutes: const Value(30),
        method: 'SELF',
        status: 'APPROVED',
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cuadrilla A'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Horas'));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('8h 0m'), findsOneWidget, reason: '8h30 menos 30 de descanso');
    expect(find.text('0h 0m'), findsOneWidget, reason: 'María sin jornadas esta semana');
    await desmontar(tester);
  });

  testWidgets('con dos cuadrillas, primero la lista y el toque abre la elegida', (tester) async {
    await cuadrilla('cr1', 'Cuadrilla A', gente: [('m1', 'María López')]);
    await cuadrilla('cr2', 'Cuadrilla B', gente: [('m1', 'María López'), ('m3', 'Pedro Mora')]);
    await asignadaHoy('m1');

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Cuadrilla A'), findsOneWidget);
    expect(find.text('Cuadrilla B'), findsOneWidget);
    expect(find.text('Personas'), findsNothing, reason: 'todavía no se entró a ninguna');

    await tester.tap(find.text('Cuadrilla B'));
    await tester.pumpAndSettle();

    expect(find.text('Personas'), findsOneWidget);
    expect(find.text('Horas'), findsOneWidget);
    await desmontar(tester);
  });
}
