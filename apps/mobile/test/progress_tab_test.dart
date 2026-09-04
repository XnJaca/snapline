import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/api/models/project_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/features/projects/progress_tab.dart';

import 'support/fakes.dart';

/// La tab Avance: cómo va la obra, de un vistazo.
///
/// Lo que se verifica acá es que la pantalla responda **dónde está** sin
/// desplazarse, y que no afirme nada que nadie registró — ni un porcentaje, ni
/// una posición para una obra cancelada.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> obra({
    ProjectStatus status = ProjectStatus.inProgress,
    DateTime? creada,
  }) =>
      seedProject(db,
          id: 'p1',
          name: 'Techo Martinez',
          customerName: 'Martinez',
          status: status,
          createdAt: creada ?? DateTime(2026, 8, 12));

  Future<void> foto({
    required String id,
    List<String> tags = const [],
    required DateTime cuando,
  }) =>
      db.into(db.mediaAssets).insert(MediaAssetsCompanion.insert(
            id: id,
            companyId: 'c1',
            updatedAt: cuando,
            projectId: 'p1',
            kind: 'PHOTO',
            mime: 'image/jpeg',
            visibility: 'INTERNAL',
            uploadStatus: 'READY',
            capturedAt: Value(cuando),
            tags: Value(jsonEncode(tags)),
          ));

  Future<void> jornada({
    required String id,
    required DateTime entrada,
    required DateTime salida,
  }) =>
      db.into(db.timeEntries).insert(TimeEntriesCompanion.insert(
            id: id,
            companyId: 'c1',
            updatedAt: entrada,
            projectId: 'p1',
            membershipId: 'm1',
            recordedByMembershipId: 'm1',
            clockInAt: entrada,
            clockOutAt: Value(salida),
            method: 'SELF',
            status: 'APPROVED',
          ));

  Future<void> nota({required String body, required DateTime cuando}) =>
      db.into(db.projectUpdates).insert(ProjectUpdatesCompanion.insert(
            id: 'n1',
            companyId: 'c1',
            updatedAt: cuando,
            projectId: 'p1',
            authorMembershipId: 'm1',
            body: body,
            visibility: 'INTERNAL',
          ));

  /// Un teléfono de verdad, no los 800x600 del default: esta pantalla promete
  /// responder sin desplazarse, y eso se mide en el alto que existe.
  Future<void> montar(
    WidgetTester tester, {
    AuthUserDtoLocale locale = AuthUserDtoLocale.es,
    List<String>? permisos,
    ThemeMode theme = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testWidget(
      db: db,
      locale: locale,
      themeMode: theme,
      session: buildSession(locale: locale, permissions: permisos),
      child: const ProgressTab(projectId: 'p1'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWithApp('lo primero es el estado, no lo que pasó', (tester) async {
    await obra();
    await montar(tester);

    // Dos veces a propósito: el titular y su peldaño en la escalera.
    expect(find.text('En proceso'), findsNWidgets(2));
  });

  testWithApp('la escalera marca hasta dónde llegó la obra', (tester) async {
    await obra(status: ProjectStatus.scheduled);
    await montar(tester);

    // Los cinco peldaños del camino, con el actual entre ellos.
    for (final peldano in ['Prospecto', 'Estimado', 'Terminado']) {
      expect(find.text(peldano), findsOne);
    }
    // El actual, en el titular y en su peldaño.
    expect(find.text('Agendado'), findsNWidgets(2));
  });

  testWithApp('una obra cancelada no se ubica en el camino', (tester) async {
    // No está en ningún punto: mostrarla sobre la escalera diría que avanza.
    await obra(status: ProjectStatus.cancelled);
    await montar(tester);

    expect(find.text('Cancelado'), findsOne);
    expect(find.text('Prospecto'), findsNothing);
  });

  testWithApp('una obra en pausa cae donde la ejecución', (tester) async {
    // `ON_HOLD` es una pausa dentro de la ejecución, no una etapa propia.
    await obra(status: ProjectStatus.onHold);
    await montar(tester);

    expect(find.text('En pausa'), findsOne);
    expect(find.text('En proceso'), findsOne);
    expect(find.text('Terminado'), findsOne);
  });

  testWithApp('la pantalla no inventa un porcentaje', (tester) async {
    // Nadie calcula «45% del techo», y un número inventado termina
    // repitiéndosele al cliente como si estuviera respaldado.
    await obra();
    await jornada(
      id: 't1',
      entrada: DateTime(2026, 8, 25, 7),
      salida: DateTime(2026, 8, 25, 15),
    );
    await montar(tester);

    expect(find.textContaining('%'), findsNothing);
  });

  testWithApp('el par es el antes contra la más reciente', (tester) async {
    // La derecha es la última foto, no la etiquetada `AFTER`: esa recién
    // existe al terminar, y la pantalla tiene que servir mientras dura.
    await obra();
    await foto(id: 'f1', tags: ['BEFORE'], cuando: DateTime(2026, 8, 14));
    await foto(id: 'f2', tags: ['DURING'], cuando: DateTime(2026, 8, 30));
    await montar(tester);

    expect(find.text('Antes'), findsOne);
    expect(find.text('Lo último'), findsOne);
  });

  testWithApp('sin foto del antes se dice cuándo hay que tomarla', (
    tester,
  ) async {
    // Una vez que el trabajo empezó, ese antes ya no existe.
    await obra();
    await foto(id: 'f1', tags: ['DURING'], cuando: DateTime(2026, 8, 30));
    await montar(tester);

    expect(find.textContaining('antes de comenzar el trabajo'), findsOne);
  });

  testWithApp('las horas son una cifra, no una lista de días', (tester) async {
    await obra();
    await jornada(
      id: 't1',
      entrada: DateTime(2026, 8, 25, 7),
      salida: DateTime(2026, 8, 25, 15),
    );
    await jornada(
      id: 't2',
      entrada: DateTime(2026, 8, 26, 7),
      salida: DateTime(2026, 8, 26, 12),
    );
    await montar(tester);

    expect(find.text('13h 0m'), findsOne);
    expect(find.text('Trabajadas'), findsOne);
    expect(find.text('Días en obra'), findsOne);
  });

  testWithApp('la última nota se lee sin abrir nada', (tester) async {
    await obra();
    await nota(body: 'Faltan las tejas del norte', cuando: DateTime(2026, 8, 30));
    await montar(tester);

    expect(find.text('Faltan las tejas del norte'), findsOne);
  });

  testWithApp('el hilo queda a un toque, con su conteo', (tester) async {
    await obra();
    await foto(id: 'f1', tags: ['BEFORE'], cuando: DateTime(2026, 8, 14));
    await montar(tester);

    expect(find.text('Ver todo lo que pasó'), findsOne);
    // El día con foto y el ancla de la obra.
    expect(find.textContaining('2 movimientos'), findsOne);
  });

  testWithApp('sin projects.write no se ofrece escribir', (tester) async {
    await obra();
    await montar(tester, permisos: const ['projects.read', 'media.read']);

    expect(find.text('Escribir nota'), findsNothing);
  });

  testWithApp('con permiso, la acción está', (tester) async {
    await obra();
    await montar(tester);

    expect(find.text('Escribir nota'), findsOne);
  });

  testWithApp('nada quemado: en inglés la pantalla sale en inglés', (
    tester,
  ) async {
    await obra();
    await montar(tester, locale: AuthUserDtoLocale.en);

    expect(find.text('In progress'), findsNWidgets(2));
    expect(find.text('Where it started, where it stands'), findsOne);
    expect(find.text('See everything that happened'), findsOne);
  });

  for (final (nombre, theme) in [
    ('claro', ThemeMode.light),
    ('oscuro', ThemeMode.dark),
  ]) {
    testWithApp('$nombre: la pantalla se dibuja sin desbordes', (tester) async {
      await obra();
      await foto(id: 'f1', tags: ['BEFORE'], cuando: DateTime(2026, 8, 14));
      await jornada(
        id: 't1',
        entrada: DateTime(2026, 8, 25, 7),
        salida: DateTime(2026, 8, 25, 15),
      );
      await nota(body: 'Una nota larga ' * 12, cuando: DateTime(2026, 8, 30));
      await montar(tester, theme: theme);

      expect(tester.takeException(), isNull);
    });
  }
}
