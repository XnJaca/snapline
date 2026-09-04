import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/media_client.dart';
import 'package:snapline/api/models/signed_url_dto.dart';
import 'package:snapline/core/media/media_paths.dart';
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
    // Sin `path_provider` en un test: se le dice dónde están los archivos.
    MediaPaths.usarCarpeta(dir.path);
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

  group('lo que se vio probando en el teléfono', () {
    test('la etiqueta viaja dentro del registro, no como operación aparte',
        () async {
      final archivo = File('${dir.path}/foto.jpg')..writeAsBytesSync([1, 2, 3]);

      await media.registerPhoto(
        projectId: 'p1',
        filePath: archivo.path,
        companyId: 'co1',
        tags: [MediaTag.before],
      );

      final pendientes = await Outbox(db, const Uuid()).pending();
      // Una sola operación: dos con el mismo instante no tienen orden
      // garantizado en el lote, y la etiqueta llegaba antes que su foto.
      expect(pendientes, hasLength(1));
      expect(pendientes.single.type, SyncOp.mediaRegister);
      expect(jsonDecode(pendientes.single.payload)['tags'], ['BEFORE']);
    });

    test('sin etiquetas el payload no manda la clave vacía', () async {
      final archivo = File('${dir.path}/foto2.jpg')..writeAsBytesSync([1]);

      await media.registerPhoto(
        projectId: 'p1',
        filePath: archivo.path,
        companyId: 'co1',
      );

      final payload = jsonDecode(
          (await Outbox(db, const Uuid()).pending()).single.payload) as Map;
      expect(payload.containsKey('tags'), isFalse);
    });

    test('subir el binario apaga "guardada en el teléfono"', () async {
      final archivo = File('${dir.path}/foto3.jpg')..writeAsBytesSync([1]);
      final id = await media.registerPhoto(
        projectId: 'p1',
        filePath: archivo.path,
        companyId: 'co1',
      );

      expect((await media.watchDeLaObra('p1').first).single.subida, isFalse);

      await media.markUploaded(id);

      // Sin esto la galería esperaba un pull que no llega solo: nada vuelve a
      // encolarse, así que la foto quedaba con cara de no haber subido.
      expect((await media.watchDeLaObra('p1').first).single.subida, isTrue);
    });
  });

  group('borrar una foto', () {
    test('la saca de la galería y encola la baja', () async {
      await sembrarAsset('a1');

      await media.borrar('a1');

      expect(await media.watchDeLaObra('p1').first, isEmpty);
      final pendientes = await Outbox(db, const Uuid()).pending();
      expect(pendientes.single.type, SyncOp.mediaDelete);
      expect(pendientes.single.targetId, 'a1');
    });

    test('es borrado suave: la fila queda para poder propagar la baja',
        () async {
      await sembrarAsset('a1');

      await media.borrar('a1');

      final fila = await (db.select(db.mediaAssets)
            ..where((m) => m.id.equals('a1')))
          .getSingle();
      expect(fila.deletedAt != null, isTrue,
          reason: 'un borrado duro no llega a un teléfono que estuvo sin señal');
    });

    test('el archivo del teléfono sí se borra de verdad', () async {
      final archivo = File('${dir.path}/borrable.jpg')..writeAsBytesSync([1]);
      await sembrarAsset('a1');
      await db.into(db.pendingUploads).insert(
        PendingUploadsCompanion.insert(
          assetId: 'a1',
          filePath: archivo.path,
          mime: 'image/jpeg',
        ),
      );

      await media.borrar('a1');

      expect(archivo.existsSync(), isFalse);
      // Y deja de intentar subir algo que ya no existe.
      expect(await media.pendingUploads(), isEmpty);
    });
  });

  group('la ruta del archivo sobrevive a una reinstalación', () {
    test('la foto se sigue viendo aunque el contenedor haya cambiado',
        () async {
      final archivo = File('${dir.path}/techo.jpg')..writeAsBytesSync([1, 2, 3]);
      final id = await media.registerPhoto(
        projectId: 'p1',
        filePath: archivo.path,
        companyId: 'co1',
      );

      // Lo que hace iOS al reinstalar: mismo archivo, contenedor nuevo.
      final nuevoContenedor =
          Directory.systemTemp.createTempSync('snapline_contenedor');
      addTearDown(() => nuevoContenedor.deleteSync(recursive: true));
      File('${nuevoContenedor.path}/techo.jpg').writeAsBytesSync([1, 2, 3]);
      MediaPaths.usarCarpeta(nuevoContenedor.path);

      final foto = (await media.watchDeLaObra('p1').first).single;
      expect(foto.id, id);
      expect(foto.enElTelefono, isTrue,
          reason: 'la ruta se resuelve contra la carpeta de hoy');
      expect(foto.localPath, '${nuevoContenedor.path}/techo.jpg');

      MediaPaths.usarCarpeta(dir.path);
    });

    test('si el binario ya no está, no se dice que está en el teléfono',
        () async {
      final archivo = File('${dir.path}/perdida.jpg')..writeAsBytesSync([1]);
      await media.registerPhoto(
        projectId: 'p1',
        filePath: archivo.path,
        companyId: 'co1',
      );
      archivo.deleteSync();

      final foto = (await media.watchDeLaObra('p1').first).single;
      // Antes decía "guardada en el teléfono" y `Image.file` explotaba con un
      // archivo que no existe.
      expect(foto.enElTelefono, isFalse);
    });
  });

  group('la URL firmada', () {
    late _MediaContador cliente;
    late MediaRepository repo;

    setUp(() {
      cliente = _MediaContador();
      repo = MediaRepository(db, Outbox(db, const Uuid()), const Uuid(), cliente);
      MediaRepository.olvidarFirmas();
    });

    test('se pide una vez y se reusa mientras la firma viva', () async {
      // Sin caché, cada montaje de un widget con foto —cambiar de tab basta—
      // pide una firma nueva; y como cada firma es otra URL, el binario se
      // vuelve a bajar de Backblaze. Una llamada y una descarga por vuelta.
      final primera = await repo.urlParaVer('a1');
      final segunda = await repo.urlParaVer('a1');

      expect(cliente.llamadas, 1);
      expect(segunda, primera);
    });

    test('vencida se vuelve a pedir', () async {
      // El margen que se le resta al TTL es de un minuto, así que con 30
      // segundos la firma nace ya vencida.
      cliente.ttl = 30;
      final primera = await repo.urlParaVer('a1');
      final segunda = await repo.urlParaVer('a1');

      expect(cliente.llamadas, 2);
      expect(segunda, isNot(primera));
    });

    test('cada foto tiene la suya', () async {
      await repo.urlParaVer('a1');
      await repo.urlParaVer('a2');

      expect(cliente.llamadas, 2);
    });

    test('cerrar sesión las olvida', () async {
      // El teléfono es de la empresa y lo usa más de una persona: una firma
      // viva es acceso a una foto que la próxima sesión puede no tener.
      await repo.urlParaVer('a1');
      MediaRepository.olvidarFirmas();
      await repo.urlParaVer('a1');

      expect(cliente.llamadas, 2);
    });
  });

}

/// Un cliente que cuenta cuántas firmas pidió.
class _MediaContador implements MediaClient {
  int llamadas = 0;
  int ttl = 600;

  @override
  Future<SignedUrlDto> mediaDownloadUrl({required String id}) async {
    llamadas++;
    return SignedUrlDto(
      url: 'https://b2.example/$id?firma=$llamadas',
      expiresInSeconds: ttl,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('el test no debería llamar a esto');
}
