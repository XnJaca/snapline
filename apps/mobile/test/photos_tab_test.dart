import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/media/media_paths.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/media_repository.dart';
import 'package:snapline/features/projects/photo_tag_sheet.dart';
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

  Future<void> sembrarFoto(
    String id, {
    List<String> tags = const [],
    DateTime? cuando,
    String uploadStatus = 'READY',
  }) async {
    await db.into(db.mediaAssets).insert(
      MediaAssetsCompanion.insert(
        id: id,
        companyId: 'c1',
        updatedAt: DateTime(2026, 8, 12),
        projectId: 'p1',
        kind: 'PHOTO',
        mime: 'image/jpeg',
        visibility: 'INTERNAL',
        uploadStatus: uploadStatus,
        capturedAt: Value(cuando ?? DateTime(2026, 8, 12)),
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

  group('el orden de los grupos', () {
    ObraFoto foto(String id, List<MediaTag> tags) => ObraFoto(
          id: id,
          projectId: 'p1',
          visibility: 'INTERNAL',
          capturedAt: DateTime(2026, 8, 12),
          tags: tags,
          localPath: null,
          subida: true,
          fallida: false,
        );

    test('sigue el del dominio, no el de la fecha', () {
      final grupos = agruparPorEtiqueta([
        foto('suelta', const []),
        foto('despues', const [MediaTag.after]),
        foto('antes', const [MediaTag.before]),
      ]);

      expect(grupos.map((g) => g.tag),
          [MediaTag.before, MediaTag.after, null]);
    });

    test('lo que no tiene etiqueta va último, nunca primero', () {
      final grupos = agruparPorEtiqueta([
        foto('suelta', const []),
        foto('recibo', const [MediaTag.receipt]),
      ]);

      expect(grupos.last.tag, isNull);
    });

    test('una foto con dos etiquetas está en los dos grupos', () {
      final grupos = agruparPorEtiqueta([
        foto('a1', const [MediaTag.before, MediaTag.detail]),
      ]);

      expect(grupos.map((g) => g.tag), [MediaTag.before, MediaTag.detail]);
      expect(grupos.every((g) => g.fotos.single.id == 'a1'), isTrue);
    });

    test('un grupo sin fotos no se dibuja', () {
      final grupos = agruparPorEtiqueta([foto('a1', const [MediaTag.before])]);

      expect(grupos, hasLength(1));
    });
  });

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

  testWidgets('la etiqueta encabeza su grupo', timeout: limite, (tester) async {
    await sembrarFoto('a1', tags: ['BEFORE']);

    await tester.pumpWidget(pantalla());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Antes'), findsOne);
    await disposeApp(tester);
  });

  testWidgets('una foto con dos etiquetas está en los dos grupos',
      timeout: limite, (tester) async {
    await sembrarFoto('a1', tags: ['BEFORE', 'DETAIL']);

    await tester.pumpWidget(pantalla());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Antes'), findsOne);
    expect(find.text('Detalle'), findsOne);
    await disposeApp(tester);
  });

  testWidgets('el WORKER puede tocar la foto: etiquetar es parte de capturar',
      timeout: limite, (tester) async {
    await sembrarFoto('a1');

    await tester.pumpWidget(pantalla(permisos: const [
      'media.read',
      'media.capture',
      'projects.read',
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final celda = tester.widget<InkWell>(find.byType(InkWell).first);
    expect(celda.onTap, isNotNull);
    await disposeApp(tester);
  });

  testWidgets('quien solo mira no puede tocar nada', timeout: limite,
      (tester) async {
    await sembrarFoto('a1');

    await tester.pumpWidget(
        pantalla(permisos: const ['media.read', 'projects.read']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final celda = tester.widget<InkWell>(find.byType(InkWell).first);
    expect(celda.onTap, isNull,
        reason: 'sin media.capture ni media.visibility no hay nada que hacer');
    await disposeApp(tester);
  });

  testWidgets('el WORKER no ve las acciones de visibilidad en la hoja',
      timeout: limite, (tester) async {
    await sembrarFoto('a1');

    await tester.pumpWidget(pantalla(permisos: const [
      'media.read',
      'media.capture',
      'projects.read',
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Poner etiqueta'), findsOne);
    expect(find.text('Mostrar al cliente'), findsNothing);
    expect(find.text('Publicar'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('el OWNER sí las ve, y solo el próximo escalón',
      timeout: limite, (tester) async {
    await sembrarFoto('a1');

    await tester.pumpWidget(pantalla());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Mostrar al cliente'), findsOne);
    // Desde INTERNAL no se ofrece publicar: la escalera sube de a uno y el
    // servidor lo rechazaría.
    expect(find.text('Publicar'), findsNothing);
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

  group('la hoja de etiquetas', () {
    Future<void> abrir(WidgetTester tester) async {
      await tester.pumpWidget(testWidget(
        db: db,
        child: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => mostrarHojaDeEtiquetas(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('la acción de guardar se ve sin elegir nada, y dice qué hará',
        timeout: limite, (tester) async {
      await abrir(tester);

      // El bug que se vio en el teléfono: el botón existía y quedaba debajo de
      // la barra gestual. Que esté en el árbol no alcanza — tiene que estar
      // dentro de la pantalla.
      expect(find.text('Guardar sin etiqueta'), findsOne);
      final boton = tester.getRect(find.text('Guardar sin etiqueta'));
      final pantalla = tester.getRect(find.byType(MaterialApp));
      expect(boton.bottom, lessThanOrEqualTo(pantalla.bottom));

      await disposeApp(tester);
    });

    testWidgets('al elegir una, la acción cambia y guarda esa etiqueta',
        timeout: limite, (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Antes'));
      await tester.pumpAndSettle();

      expect(find.text('Guardar'), findsOne);
      expect(find.text('Guardar sin etiqueta'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('las seis etiquetas del dominio están, cada una con su icono',
        timeout: limite, (tester) async {
      await abrir(tester);

      for (final tag in MediaTag.values) {
        expect(find.byIcon(etiquetaEnIcono(tag)), findsWidgets,
            reason: 'falta el icono de ${tag.name}');
      }

      await disposeApp(tester);
    });
  });

  group('de dónde sale la imagen', () {
    testWidgets('la que está en el teléfono se dibuja desde el archivo',
        timeout: limite, (tester) async {
      final archivo = File('${Directory.systemTemp.path}/snapline-mini.jpg')
        ..writeAsBytesSync(_jpegDeUnPixel);
      addTearDown(() => archivo.deleteSync());
      // Sin `path_provider` en un test: se le dice dónde buscar los archivos.
      MediaPaths.usarCarpeta(Directory.systemTemp.path);
      addTearDown(() => MediaPaths.usarCarpeta(''));

      await sembrarFoto('a1', uploadStatus: 'PENDING');
      await db.into(db.pendingUploads).insert(
        PendingUploadsCompanion.insert(
          assetId: 'a1',
          filePath: archivo.path,
          mime: 'image/jpeg',
        ),
      );

      await tester.pumpWidget(pantalla());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Image), findsWidgets);
      await disposeApp(tester);
    });

    testWidgets('la que ya no está y no subió lo dice, sin cuadro roto',
        timeout: limite, (tester) async {
      // Pasa tras cerrar sesión: se limpia lo local y el binario nunca llegó.
      await sembrarFoto('a1', uploadStatus: 'PENDING');

      await tester.pumpWidget(pantalla());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOne);
      expect(tester.takeException(), isNull);
      await disposeApp(tester);
    });

    testWidgets('la subida sin archivo local se pide firmada al servidor',
        timeout: limite, (tester) async {
      await sembrarFoto('a1');

      await tester.pumpWidget(pantalla());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // El cliente de media del test lanza: lo que importa es que se haya
      // intentado por red en vez de mostrar el marcador de "no está".
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      await disposeApp(tester);
    });
  });

  group('borrar desde la hoja', () {
    Future<void> abrirAcciones(WidgetTester tester) async {
      await sembrarFoto('a1');
      await tester.pumpWidget(pantalla());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
    }
    testWidgets('pregunta antes, y las dos salidas se ven como botones',
        timeout: limite, (tester) async {
      await abrirAcciones(tester);
      // La hoja es más alta que la pantalla del test: sin esto el toque cae
      // fuera del árbol y no pasa nada.
      await tester.ensureVisible(find.text('Borrar la foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar la foto'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar esta foto?'), findsOne);
      // Las dos son botones de verdad, no texto suelto: con guantes, un
      // TextButton de diálogo no se lee ni se acierta.
      expect(find.widgetWithText(FilledButton, 'Sí, borrar'), findsOne);
      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsOne);
      await disposeApp(tester);
    });
    testWidgets('cancelar no borra nada', timeout: limite, (tester) async {
      await abrirAcciones(tester);
      // La hoja es más alta que la pantalla del test: sin esto el toque cae
      // fuera del árbol y no pasa nada.
      await tester.ensureVisible(find.text('Borrar la foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar la foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      final fila = await (db.select(db.mediaAssets)
            ..where((m) => m.id.equals('a1')))
          .getSingle();
      expect(fila.deletedAt == null, isTrue);
      await disposeApp(tester);
    });
  });
}

/// El JPEG válido más chico que existe. Sin bytes reales `Image.file` lanza.
final _jpegDeUnPixel = base64Decode(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
  'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA'
  'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==')
;
