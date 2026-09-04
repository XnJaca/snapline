import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/features/projects/progress_history_screen.dart';

import 'support/fakes.dart';

/// El hilo, en pantalla.
///
/// Lo que se verifica acá es lo que no se ve leyendo el repositorio: que un
/// ancla no se lea como una transición, que una nota interna no lleve marca, y
/// que nada esté quemado en un idioma.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> sembrarHito({
    required String id,
    String? from,
    required String to,
    String? autor = 'm1',
    DateTime? cuando,
  }) async {
    final momento = cuando ?? DateTime(2026, 8, 29, 8);
    await db.into(db.projectStatusChanges).insert(
          ProjectStatusChangesCompanion.insert(
            id: id,
            companyId: 'c1',
            updatedAt: momento,
            projectId: 'p1',
            fromStatus: Value(from),
            toStatus: to,
            changedByMembershipId: Value(autor),
            deviceRecordedAt: momento,
            serverReceivedAt: momento,
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
    if (autor != null) {
      await db.into(db.people).insert(
            PeopleCompanion.insert(
              membershipId: autor,
              name: 'William Ferman',
              role: 'OWNER',
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> sembrarNota({
    required String id,
    required String body,
    String visibility = 'INTERNAL',
    DateTime? cuando,
    SyncStatus estado = SyncStatus.synced,
  }) async {
    final momento = cuando ?? DateTime(2026, 8, 30, 17);
    await db.into(db.projectUpdates).insert(
          ProjectUpdatesCompanion.insert(
            id: id,
            companyId: 'c1',
            updatedAt: momento,
            projectId: 'p1',
            authorMembershipId: 'm1',
            body: body,
            visibility: visibility,
            publishedAt: Value(visibility == 'CLIENT' ? momento : null),
            syncStatus: Value(estado),
          ),
        );
  }

  Future<void> sembrarFoto({
    required String id,
    List<String> tags = const [],
    DateTime? cuando,
  }) async {
    final momento = cuando ?? DateTime(2026, 8, 28, 10);
    await db.into(db.mediaAssets).insert(
          MediaAssetsCompanion.insert(
            id: id,
            companyId: 'c1',
            updatedAt: momento,
            projectId: 'p1',
            kind: 'PHOTO',
            mime: 'image/jpeg',
            visibility: 'INTERNAL',
            uploadStatus: 'READY',
            capturedAt: Value(momento),
            tags: Value(jsonEncode(tags)),
          ),
        );
  }

  Future<void> montar(
    WidgetTester tester, {
    AuthUserDtoLocale locale = AuthUserDtoLocale.es,
    List<String>? permisos,
    ThemeMode theme = ThemeMode.light,
  }) async {
    await tester.pumpWidget(testWidget(
      db: db,
      locale: locale,
      themeMode: theme,
      session: buildSession(locale: locale, permissions: permisos),
      child: const ProgressHistoryScreen(projectId: 'p1'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWithApp('sin nada todavía explica qué va a aparecer, no fiscaliza', (
    tester,
  ) async {
    await montar(tester);

    expect(find.textContaining('Todavía no hay nada registrado'), findsOne);
    // El copy no le reclama nada a nadie: dice qué va a pasar, no qué falta.
    expect(find.textContaining('van a aparecer'), findsOne);
  });

  testWithApp('un cambio de estado se lee de dónde a dónde', (tester) async {
    await sembrarHito(id: 'h1', from: 'SCHEDULED', to: 'IN_PROGRESS');
    await montar(tester);

    expect(find.textContaining('Agendado'), findsOne);
    expect(find.textContaining('En proceso'), findsOne);
    expect(find.text('William Ferman'), findsOne);
  });

  testWithApp('una obra anterior al historial ancla sin afirmar estado', (
    tester,
  ) async {
    // Lo único que se sabe es cuándo empezó. Decir que el 12 de agosto estaba
    // «En proceso» —el estado de hoy— sería inventarle un pasado.
    await seedProject(db, id: 'p1', name: 'Techo', customerName: 'Martinez',
        createdAt: DateTime(2026, 8, 12));
    await montar(tester);

    expect(find.text('Obra creada'), findsOne);
    expect(find.textContaining('→'), findsNothing);
    expect(find.textContaining('En proceso'), findsNothing);
  });

  testWithApp('una obra que nació en un estado sí lo afirma', (tester) async {
    await sembrarHito(id: 'nacida', to: 'LEAD');
    await montar(tester);

    expect(find.textContaining('Obra creada'), findsOne);
    expect(find.textContaining('Prospecto'), findsOne);
  });

  testWithApp('la etiqueta de la foto nombra la fila, no el conteo', (
    tester,
  ) async {
    // «1 foto» no dice nada; «Antes» dice en qué momento de la obra está.
    await sembrarFoto(id: 'f1', tags: ['BEFORE']);
    await montar(tester);

    expect(find.textContaining('Antes'), findsOne);
  });

  testWithApp('una nota interna no lleva marca: es el caso normal', (
    tester,
  ) async {
    await sembrarNota(id: 'n1', body: 'Faltan las tejas del lado norte');
    await montar(tester);

    expect(find.text('Faltan las tejas del lado norte'), findsOne);
    expect(find.textContaining('La ve el cliente'), findsNothing);
  });

  testWithApp('la que sale de la empresa sí la lleva', (tester) async {
    await sembrarNota(id: 'n1', body: 'Terminamos el sur', visibility: 'CLIENT');
    await montar(tester);

    expect(find.textContaining('La ve el cliente'), findsOne);
  });

  testWithApp('una nota sin sincronizar se distingue de una confirmada', (
    tester,
  ) async {
    await sembrarNota(
      id: 'n1',
      body: 'Escrita sin señal',
      estado: SyncStatus.pending,
    );
    await montar(tester);

    expect(find.textContaining('En este teléfono'), findsOne);
  });

  testWithApp('una línea separa los días entre sí', (tester) async {
    // Separa días, no filas: dos entradas del mismo día quedan del mismo lado
    // y se leen como cosas que pasaron juntas.
    await sembrarNota(id: 'n1', body: 'Una', cuando: DateTime(2026, 8, 30, 9));
    await sembrarNota(id: 'n2', body: 'Dos', cuando: DateTime(2026, 8, 30, 17));
    await sembrarNota(id: 'n3', body: 'Tres', cuando: DateTime(2026, 8, 28, 9));
    await montar(tester);

    // Dos días, una línea: la primera fecha no la lleva encima.
    expect(find.byType(Divider), findsOne);
  });

  testWithApp('lo de hoy y lo de ayer se dicen con palabras', (tester) async {
    // Es como se piensa un día de obra. «2 sep» obliga a calcular.
    final hoy = DateTime.now();
    await sembrarNota(id: 'n1', body: 'Recién', cuando: hoy);
    await sembrarNota(
      id: 'n2',
      body: 'Ayer',
      cuando: hoy.subtract(const Duration(days: 1)),
    );
    await montar(tester);

    expect(find.text('hoy'), findsOne);
    expect(find.text('ayer'), findsOne);
  });

  testWithApp('dos entradas del mismo día no repiten la fecha', (tester) async {
    // La fecha es columna: repetirla en cada fila la vuelve ruido y rompe la
    // lectura de que las dos cosas pasaron el mismo día.
    await sembrarNota(id: 'n1', body: 'Primera', cuando: DateTime(2026, 8, 30, 9));
    await sembrarNota(id: 'n2', body: 'Segunda', cuando: DateTime(2026, 8, 30, 17));
    await montar(tester);

    expect(find.text('Primera'), findsOne);
    expect(find.text('Segunda'), findsOne);
    expect(find.text('30 ago'), findsOne);
  });

  testWithApp('una entrada de otro año lleva el año', (tester) async {
    await sembrarNota(id: 'n1', body: 'Vieja', cuando: DateTime(2024, 8, 30));
    await montar(tester);

    expect(find.textContaining('2024'), findsOne);
  });

  testWithApp('nada quemado: en inglés el hilo sale en inglés', (tester) async {
    await sembrarNota(id: 'n1', body: 'Roof done', visibility: 'CLIENT');
    await montar(tester, locale: AuthUserDtoLocale.en);

    expect(find.textContaining('Visible to the customer'), findsOne);
  });

  for (final (nombre, theme) in [
    ('claro', ThemeMode.light),
    ('oscuro', ThemeMode.dark),
  ]) {
    testWithApp('$nombre: el hilo se dibuja sin desbordes', (tester) async {
      await sembrarHito(id: 'h1', from: 'SCHEDULED', to: 'IN_PROGRESS');
      await sembrarNota(id: 'n1', body: 'Una nota larga ' * 12);
      await montar(tester, theme: theme);

      expect(tester.takeException(), isNull);
    });
  }
}
