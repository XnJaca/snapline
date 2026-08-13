import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/media_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// La galería de la obra: qué entra, qué no, y qué se puede borrar del teléfono.
void main() {
  late AppDatabase db;
  late MediaRepository media;
  late Directory dir;

  setUp(() {
    db = testDatabase();
    media = MediaRepository(
        db, Outbox(db, const Uuid()), const Uuid(), MediaClientNulo());
    dir = Directory.systemTemp.createTempSync('snapline_galeria');
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> sembrarAsset(
    String id, {
    String uploadStatus = 'READY',
    String visibility = 'INTERNAL',
    List<String> tags = const [],
    DateTime? capturedAt,
  }) async {
    await db.into(db.mediaAssets).insert(
      MediaAssetsCompanion.insert(
        id: id,
        companyId: 'co1',
        updatedAt: DateTime(2026, 8, 12),
        projectId: 'p1',
        kind: 'PHOTO',
        mime: 'image/jpeg',
        visibility: visibility,
        uploadStatus: uploadStatus,
        capturedAt: Value(capturedAt ?? DateTime(2026, 8, 12)),
        tags: Value(jsonEncode(tags)),
      ),
    );
  }

  Future<void> sembrarMarcaje(String id, {String? fotoEntrada}) async {
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: id,
        companyId: 'co1',
        updatedAt: DateTime(2026, 8, 12),
        projectId: 'p1',
        membershipId: 'm1',
        recordedByMembershipId: 'm1',
        clockInAt: DateTime(2026, 8, 12, 7),
        method: 'SELF',
        status: 'PENDING',
        clockInPhotoId: Value(fotoEntrada),
      ),
    );
  }

  group('qué entra en la galería', () {
    test('la foto del marcaje no aparece; la de la obra sí', () async {
      await sembrarAsset('foto-obra');
      await sembrarAsset('foto-fichaje');
      await sembrarMarcaje('t1', fotoEntrada: 'foto-fichaje');

      final fotos = await media.watchDeLaObra('p1').first;

      expect(fotos.map((f) => f.id), ['foto-obra']);
    });

    test('la de salida tampoco', () async {
      await sembrarAsset('foto-obra');
      await sembrarAsset('foto-salida');
      await db.into(db.timeEntries).insert(
        TimeEntriesCompanion.insert(
          id: 't1',
          companyId: 'co1',
          updatedAt: DateTime(2026, 8, 12),
          projectId: 'p1',
          membershipId: 'm1',
          recordedByMembershipId: 'm1',
          clockInAt: DateTime(2026, 8, 12, 7),
          method: 'SELF',
          status: 'PENDING',
          clockOutPhotoId: const Value('foto-salida'),
        ),
      );

      final fotos = await media.watchDeLaObra('p1').first;

      expect(fotos.map((f) => f.id), ['foto-obra']);
    });

    test('una foto borrada no se muestra, aunque siga en la base', () async {
      await sembrarAsset('viva');
      await sembrarAsset('borrada');
      await (db.update(db.mediaAssets)..where((m) => m.id.equals('borrada')))
          .write(MediaAssetsCompanion(deletedAt: Value(DateTime(2026, 8, 12))));

      final fotos = await media.watchDeLaObra('p1').first;

      expect(fotos.map((f) => f.id), ['viva']);
    });

    test('las más nuevas primero: el orden es el de la obra', () async {
      await sembrarAsset('vieja', capturedAt: DateTime(2026, 8, 10));
      await sembrarAsset('nueva', capturedAt: DateTime(2026, 8, 12));

      final fotos = await media.watchDeLaObra('p1').first;

      expect(fotos.map((f) => f.id), ['nueva', 'vieja']);
    });

    test('las etiquetas llegan a la pantalla', () async {
      await sembrarAsset('a1', tags: ['BEFORE', 'DETAIL']);

      final fotos = await media.watchDeLaObra('p1').first;

      expect(fotos.single.tags, [MediaTag.before, MediaTag.detail]);
    });

    test('una etiqueta que la app no conoce no la rompe', () async {
      await sembrarAsset('a1', tags: ['BEFORE', 'INVENTADA']);

      final fotos = await media.watchDeLaObra('p1').first;

      expect(fotos.single.tags, [MediaTag.before]);
    });
  });

  group('la limpieza por espacio', () {
    Future<void> sembrarSubida(String id, int bytes, {DateTime? subidaEl}) async {
      final archivo = File('${dir.path}/$id.jpg')..writeAsBytesSync([1, 2, 3]);
      await db.into(db.pendingUploads).insert(
        PendingUploadsCompanion.insert(
          assetId: id,
          filePath: archivo.path,
          mime: 'image/jpeg',
          bytes: Value(bytes),
          uploadedAt: Value(subidaEl),
        ),
      );
    }

    test('borra las más viejas cuando se pasa del tope', () async {
      await sembrarSubida('nueva', 600, subidaEl: DateTime(2026, 8, 12));
      await sembrarSubida('vieja', 600, subidaEl: DateTime(2026, 8, 1));

      final borradas = await media.limpiarPorEspacio(topeBytes: 1000);

      expect(borradas, 1);
      final quedan = await db.select(db.pendingUploads).get();
      expect(quedan.map((p) => p.assetId), ['nueva']);
    });

    test('el archivo se borra del disco, no solo la fila', () async {
      await sembrarSubida('vieja', 2000, subidaEl: DateTime(2026, 8, 1));
      final ruta = (await db.select(db.pendingUploads).getSingle()).filePath;

      await media.limpiarPorEspacio(topeBytes: 100);

      expect(File(ruta).existsSync(), isFalse);
    });

    test('lo que no subió no se toca, por más que se pase del tope', () async {
      await sembrarSubida('sin-subir', 10_000);

      final borradas = await media.limpiarPorEspacio(topeBytes: 1);

      expect(borradas, 0);
      expect(await db.select(db.pendingUploads).get(), hasLength(1));
    });

    test('debajo del tope no borra nada', () async {
      await sembrarSubida('a', 100, subidaEl: DateTime(2026, 8, 12));
      await sembrarSubida('b', 100, subidaEl: DateTime(2026, 8, 11));

      expect(await media.limpiarPorEspacio(topeBytes: 1000), 0);
    });
  });

  group('etiquetar', () {
    test('reemplaza el conjunto y encola la operación', () async {
      await sembrarAsset('a1', tags: ['BEFORE']);

      await media.setTags('a1', [MediaTag.after, MediaTag.detail]);

      final fotos = await media.watchDeLaObra('p1').first;
      expect(fotos.single.tags, [MediaTag.after, MediaTag.detail]);

      final pendientes = await Outbox(db, const Uuid()).pending();
      expect(pendientes.single.type, SyncOp.mediaTag);
      expect(jsonDecode(pendientes.single.payload), {
        'tags': ['AFTER', 'DETAIL'],
      });
    });

    test('quitar todas también viaja', () async {
      await sembrarAsset('a1', tags: ['BEFORE']);

      await media.setTags('a1', []);

      final fotos = await media.watchDeLaObra('p1').first;
      expect(fotos.single.tags, isEmpty);
      expect((await Outbox(db, const Uuid()).pending()).single.type,
          SyncOp.mediaTag);
    });
  });
}
