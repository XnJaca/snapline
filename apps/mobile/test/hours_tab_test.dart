import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/features/projects/hours_tab.dart';

import 'support/fakes.dart';

/// Las horas de la obra, en pantalla.
///
/// Lo que se verifica acá es lo que no se ve leyendo el repositorio: que la
/// bandeja diga cuánto falta aprobar, que el botón no aparezca donde el servidor
/// va a decir que no, y que nada esté quemado en un idioma.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// El OWNER de `buildSession` es `m1`; María y Juan son otra gente.
  Future<void> sembrarJornada(
    String id, {
    String membershipId = 'maria',
    String status = 'PENDING',
    DateTime? entrada,
    DateTime? salida,
    String? decisionReason,
    String? lastRejection,
    List<String> flags = const [],
  }) async {
    final inicio = entrada ?? DateTime(2026, 8, 29, 7, 2);
    await db.into(db.timeEntries).insert(
          TimeEntriesCompanion.insert(
            id: id,
            companyId: 'c1',
            updatedAt: inicio,
            syncStatus: const Value(SyncStatus.synced),
            projectId: 'p1',
            membershipId: membershipId,
            recordedByMembershipId: membershipId,
            clockInAt: inicio,
            clockOutAt: Value(salida ?? DateTime(2026, 8, 29, 15, 40)),
            method: 'SELF',
            status: status,
            flags: Value('[${flags.map((f) => '"$f"').join(',')}]'),
            decisionReason: Value(decisionReason),
            lastRejection: Value(lastRejection),
          ),
        );
    await db.into(db.people).insert(
          PeopleCompanion.insert(
            membershipId: membershipId,
            name: membershipId == 'maria' ? 'María González' : 'Juan Ramírez',
            role: 'WORKER',
          ),
        );
  }

  Widget pantalla({
    AuthUserDtoLocale locale = AuthUserDtoLocale.es,
    List<String>? permisos,
    ThemeMode theme = ThemeMode.light,
  }) {
    return testWidget(
      db: db,
      locale: locale,
      themeMode: theme,
      session: buildSession(locale: locale, permissions: permisos),
      child: const HoursTab(projectId: 'p1'),
    );
  }

  /// Monta el tab y espera a que el stream de Drift emita.
  Future<void> montar(
    WidgetTester tester, {
    AuthUserDtoLocale locale = AuthUserDtoLocale.es,
    List<String>? permisos,
    ThemeMode theme = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      pantalla(locale: locale, permisos: permisos, theme: theme),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWithApp('sin jornadas explica por qué, no se queda muda', (tester) async {
    await montar(tester);

    expect(find.textContaining('Todavía nadie marcó'), findsOne);
  });

  testWithApp('el encabezado dice cuánto lleva la obra y cuánto falta aprobar', (tester) async {
    await sembrarJornada('t1');
    await sembrarJornada('t2', membershipId: 'juan', status: 'APPROVED');
    await montar(tester);

    expect(find.text('Horas en esta obra'), findsOne);
    expect(find.textContaining('2 personas'), findsOne);
    expect(find.textContaining('2 jornadas'), findsOne);
    // El número que convierte la pantalla en bandeja.
    expect(find.textContaining('1 sin aprobar'), findsOne);
  });

  testWithApp('la obra entera, no una ventana de siete días', (tester) async {
    // Una jornada de hace tres meses: en una vista de campo no aparecería.
    await sembrarJornada(
      't-vieja',
      entrada: DateTime(2026, 5, 4, 8),
      salida: DateTime(2026, 5, 4, 16),
    );
    await montar(tester);

    expect(find.text('María González'), findsOne);
    expect(find.textContaining('1 jornada'), findsOne);
  });

  group('quién puede decidir', () {
    testWithApp('con `time.approve` aparecen las dos acciones', (tester) async {
      await sembrarJornada('t1');
      await montar(tester);

      await tester.tap(find.text('María González'));
      await asentar(tester);

      expect(find.text('Aprobar'), findsOne);
      expect(find.text('Rechazar'), findsOne);
    });

    testWithApp('sin el permiso se ve el estado y ninguna acción', (tester) async {
      await sembrarJornada('t1');
      await montar(tester, permisos: const ['time.read']);

      await tester.tap(find.text('María González'));
      await asentar(tester);

      expect(find.text('Sin aprobar'), findsOne);
      expect(find.text('Aprobar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);
    });

    testWithApp('nadie decide sobre sus propias horas, ni el OWNER', (tester) async {
      // `m1` es la membresía de la sesión.
      await sembrarJornada('t1', membershipId: 'm1');
      await montar(tester);

      await tester.tap(find.text('Juan Ramírez'));
      await asentar(tester);

      expect(find.text('Aprobar'), findsNothing);
    });

    testWithApp('una jornada abierta no ofrece aprobar', (tester) async {
      await db.into(db.timeEntries).insert(
            TimeEntriesCompanion.insert(
              id: 'abierta',
              companyId: 'c1',
              updatedAt: DateTime(2026, 8, 31, 7),
              syncStatus: const Value(SyncStatus.synced),
              projectId: 'p1',
              membershipId: 'maria',
              recordedByMembershipId: 'maria',
              clockInAt: DateTime(2026, 8, 31, 7),
              method: 'SELF',
              status: 'PENDING',
            ),
          );
      await db.into(db.people).insert(
            PeopleCompanion.insert(
              membershipId: 'maria',
              name: 'María González',
              role: 'WORKER',
            ),
          );
      await montar(tester);

      expect(find.textContaining('Sin salida todavía'), findsOne);

      await tester.tap(find.text('María González'));
      await asentar(tester);
      expect(find.text('Aprobar'), findsNothing);
    });
  });

  testWithApp('la razón del rechazo se ve en la jornada rechazada', (tester) async {
    await sembrarJornada(
      't1',
      status: 'REJECTED',
      decisionReason: 'no estaba en la obra ese día',
    );
    await montar(tester);

    expect(find.text('Rechazada'), findsOne);

    await tester.tap(find.text('María González'));
    await asentar(tester);
    expect(find.textContaining('no estaba en la obra ese día'), findsOne);
  });

  testWithApp('un descarte del servidor se explica, traducido desde su código', (tester) async {
    await sembrarJornada('t1', lastRejection: 'PAY_RATE_MISSING');
    await montar(tester);

    // El código nunca se muestra crudo: lo traduce la capa de presentación.
    expect(find.textContaining('no tiene tarifa cargada'), findsOne);
    expect(find.textContaining('PAY_RATE_MISSING'), findsNothing);
  });

  testWithApp('las banderas del marcaje se ven con su texto', (tester) async {
    await sembrarJornada('t1', flags: const ['OUTSIDE_GEOFENCE']);
    await montar(tester);

    expect(find.text('Fuera de la obra'), findsOne);
  });

  group('nada quemado', () {
    testWithApp('en inglés sale en inglés', (tester) async {
      await sembrarJornada('t1');
      await montar(tester, locale: AuthUserDtoLocale.en);

      expect(find.text('Hours on this job'), findsOne);
      expect(find.text('To approve'), findsOne);
      expect(find.text('Horas en esta obra'), findsNothing);
    });

    testWithApp('y el estado vacío también', (tester) async {
      await montar(tester, locale: AuthUserDtoLocale.en);

      expect(find.textContaining('Nobody has clocked in'), findsOne);
    });
  });

  testWithApp('se dibuja en oscuro sin quedar ilegible', (tester) async {
    await sembrarJornada('t1');
    await montar(tester, theme: ThemeMode.dark);

    expect(find.text('María González'), findsOne);
    expect(tester.takeException(), isNull);
  });
}
