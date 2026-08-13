import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/features/projects/photos_tab.dart';

import 'support/fakes.dart';

/// La galería de la obra, en pantalla.
///
/// Lo que se verifica acá es lo que no se ve leyendo el repositorio: que el
/// estado vacío explique en vez de quedar mudo, que la acción de publicar no
/// aparezca para quien no puede, y que nada esté quemado en un idioma.
void main() {
  // Si algo no asienta, que falle con su error en vez de colgar la suite.
  const limite = Timeout(Duration(seconds: 15));

  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> sembrarFoto(String id, {List<String> tags = const []}) async {
    await db.into(db.mediaAssets).insert(
      MediaAssetsCompanion.insert(
        id: id,
        companyId: 'c1',
        updatedAt: DateTime(2026, 8, 12),
        projectId: 'p1',
        kind: 'PHOTO',
        mime: 'image/jpeg',
        visibility: 'INTERNAL',
        uploadStatus: 'READY',
        capturedAt: Value(DateTime(2026, 8, 12)),
        tags: Value(jsonEncode(tags)),
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
      child: const PhotosTab(projectId: 'p1'),
    );
  }

  testWidgets('sin fotos explica para qué sirven, no se queda muda', timeout: limite, (tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Todavía no hay fotos'), findsOne);
    expect(find.textContaining('terminan en la página'), findsOne);
    // La acción de tomar la foto está desde el primer momento.
    expect(find.text('Tomar foto'), findsOne);
    await disposeApp(tester);
  });

  testWidgets('la etiqueta se ve sobre la miniatura, sin abrir la foto', timeout: limite, (tester) async {
    await sembrarFoto('a1', tags: ['BEFORE']);

    await tester.pumpWidget(pantalla());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Antes'), findsOne);
    await disposeApp(tester);
  });

  testWidgets('el WORKER no ve dónde tocar para cambiar el nivel', timeout: limite, (tester) async {
    await sembrarFoto('a1');

    await tester.pumpWidget(pantalla(permisos: const [
      'media.read',
      'media.capture',
      'projects.read',
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final celda = tester.widget<InkWell>(find.byType(InkWell).first);
    expect(celda.onTap, isNull,
        reason: 'sin media.visibility la miniatura no abre la hoja');
    await disposeApp(tester);
  });

  testWidgets('el OWNER sí', timeout: limite, (tester) async {
    await sembrarFoto('a1');

    await tester.pumpWidget(pantalla());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final celda = tester.widget<InkWell>(find.byType(InkWell).first);
    expect(celda.onTap, isNotNull);
    await disposeApp(tester);
  });

  testWidgets('nada quemado: en inglés sale en inglés', timeout: limite, (tester) async {
    await tester.pumpWidget(pantalla(locale: AuthUserDtoLocale.en));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Take photo'), findsOne);
    expect(find.text('Tomar foto'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('se dibuja en oscuro sin romperse', timeout: limite, (tester) async {
    await sembrarFoto('a1', tags: ['AFTER']);

    await tester.pumpWidget(pantalla(theme: ThemeMode.dark));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Después'), findsOne);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });
}
