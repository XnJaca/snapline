import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../api/clients/media_client.dart';
import '../../api/models/set_visibility_dto.dart';
import '../../api/models/set_visibility_dto_visibility.dart';
import '../../core/network/api_client.dart';
import '../local/app_database.dart';
import '../local/tables.dart';
import '../sync/outbox.dart';

/// Las etiquetas del dominio, en el orden en que se ofrecen.
///
/// `BEFORE` y `AFTER` primero porque son las que alimentan el par antes/después,
/// que es la pieza de marketing del producto.
enum MediaTag { before, after, during, detail, problem, receipt }

extension MediaTagJson on MediaTag {
  /// El valor del contrato: `BEFORE`, `AFTER`, …
  String get json => name.toUpperCase();
}

/// Una foto de la obra como la muestra la galería.
class ObraFoto {
  const ObraFoto({
    required this.id,
    required this.projectId,
    required this.visibility,
    required this.capturedAt,
    required this.tags,
    required this.localPath,
    required this.subida,
    required this.fallida,
  });

  final String id;
  final String projectId;
  final String visibility;
  final DateTime? capturedAt;
  final List<MediaTag> tags;

  /// El archivo en el teléfono, mientras siga estando. Sin él la foto necesita
  /// red para verse.
  final String? localPath;

  final bool subida;

  /// Reintentó y sigue sin subir. No se descarta nunca: se dice.
  final bool fallida;

  bool get enElTelefono => localPath != null;
}

/// A partir de acá la galería lo dice en vez de callarse. No es un tope de
/// reintentos: se sigue intentando, pero deja de parecer que va bien.
const intentosParaMarcarFallida = 5;

/// El presupuesto de disco para fotos ya subidas (SPEC-0010). A ~1,5 MB por
/// foto de obra son unas 330 siempre disponibles sin señal.
const topeDeFotosBytes = 500 * 1024 * 1024;

/// Registra fotos y deja el binario esperando su subida.
///
/// El registro viaja por la bandeja como cualquier mutación; el archivo pesa y
/// sube aparte, con reintento (regla 19: el checksum desduplica). Nada de esto
/// espera a la red.
class MediaRepository {
  const MediaRepository(this._db, this._outbox, this._uuid, this._media);

  final AppDatabase _db;
  final Outbox _outbox;
  final Uuid _uuid;
  final MediaClient _media;

  /// Registra una foto tomada en el dispositivo y devuelve el id del asset.
  ///
  /// El id nace acá y es el definitivo (regla 18): el marcaje puede referirlo
  /// antes de que el servidor sepa que existe.
  Future<String> registerPhoto({
    required String projectId,
    required String filePath,
    String mime = 'image/jpeg',
    DateTime? capturedAt,
    String? companyId,
    List<MediaTag> tags = const [],
  }) async {
    final id = _uuid.v7();
    final cuando = capturedAt ?? DateTime.now();
    // Síncrono a propósito: la foto viene acotada de la cámara (<1 MB) y esto
    // corre en cuanto vuelve de ella. El I/O real asíncrono además no completa
    // bajo el reloj falso de los widget tests.
    final bytes = File(filePath).readAsBytesSync();
    final checksum = sha256.convert(bytes).toString();

    await _db.transaction(() async {
      await _db.into(_db.pendingUploads).insert(
        PendingUploadsCompanion.insert(
          assetId: id,
          filePath: filePath,
          mime: mime,
          bytes: Value(bytes.length),
        ),
      );
      // La fila local existe desde el disparo: la galería la muestra ya, sin
      // esperar al servidor ni a que suba el binario.
      if (companyId != null) {
        await _db.into(_db.mediaAssets).insert(
          MediaAssetsCompanion.insert(
            id: id,
            companyId: companyId,
            updatedAt: cuando,
            projectId: projectId,
            kind: 'PHOTO',
            mime: mime,
            visibility: 'INTERNAL',
            uploadStatus: 'PENDING',
            capturedAt: Value(cuando),
            tags: Value(jsonEncode(tags.map((t) => t.json).toList())),
            syncStatus: const Value(SyncStatus.pending),
          ),
        );
      }
      await _outbox.enqueue(
        type: SyncOp.mediaRegister,
        targetId: id,
        payload: {
          'id': id,
          'projectId': projectId,
          'kind': 'PHOTO',
          'mime': mime,
          'checksum': checksum,
          'bytes': bytes.length,
          'capturedAt': cuando.toUtc().toIso8601String(),
          // Adentro del registro y no como operación aparte: dos operaciones
          // con el mismo instante no tienen orden garantizado en el lote, y la
          // etiqueta llegaba antes que la foto la mitad de las veces.
          if (tags.isNotEmpty) 'tags': tags.map((t) => t.json).toList(),
        },
        occurredAt: cuando,
      );
    });

    return id;
  }

  /// Las fotos de la obra, más nuevas primero.
  ///
  /// **Excluye las del marcaje**: un asset referenciado por un `time_entry` es
  /// evidencia de asistencia, no material de la obra. Mezcladas, una obra de dos
  /// semanas abre con cuarenta fichajes antes de la primera foto del techo.
  Stream<List<ObraFoto>> watchDeLaObra(String projectId) {
    final query = _db.select(_db.mediaAssets)
      ..where((m) =>
          m.projectId.equals(projectId) &
          m.deletedAt.isNull() &
          m.kind.equals('PHOTO') &
          notExistsQuery(
            _db.selectOnly(_db.timeEntries)
              ..addColumns([_db.timeEntries.id])
              ..where(_db.timeEntries.clockInPhotoId.equalsExp(m.id) |
                  _db.timeEntries.clockOutPhotoId.equalsExp(m.id)),
          ))
      // Por fecha en la base; el agrupado por etiqueta lo hace la pantalla, que
      // es donde se sabe qué grupos mostrar.
      ..orderBy([
        (m) => OrderingTerm.desc(m.capturedAt),
        (m) => OrderingTerm.desc(m.updatedAt),
      ]);

    return query.join([
      leftOuterJoin(_db.pendingUploads,
          _db.pendingUploads.assetId.equalsExp(_db.mediaAssets.id)),
    ]).map((fila) {
      final asset = fila.readTable(_db.mediaAssets);
      final pendiente = fila.readTableOrNull(_db.pendingUploads);
      return ObraFoto(
        id: asset.id,
        projectId: asset.projectId,
        visibility: asset.visibility,
        capturedAt: asset.capturedAt,
        tags: _leerTags(asset.tags),
        // El archivo local es lo que hace que la galería funcione sin señal.
        // Cuando ya no está, la foto necesita red para verse.
        localPath: pendiente?.filePath,
        subida: asset.uploadStatus == 'READY',
        fallida: (pendiente?.attempts ?? 0) >= intentosParaMarcarFallida &&
            pendiente?.uploadedAt == null,
      );
    }).watch();
  }

  /// Reemplaza el conjunto entero, igual que el endpoint: reintentar es
  /// inofensivo y no hace falta propagar el borrado de una etiqueta.
  Future<void> setTags(String assetId, List<MediaTag> tags) async {
    final cuando = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.mediaAssets)..where((m) => m.id.equals(assetId)))
          .write(MediaAssetsCompanion(
        tags: Value(jsonEncode(tags.map((t) => t.json).toList())),
        updatedAt: Value(cuando),
        syncStatus: const Value(SyncStatus.pending),
      ));
      await _encolarEtiquetas(assetId, tags, cuando);
    });
  }

  Future<void> _encolarEtiquetas(
      String assetId, List<MediaTag> tags, DateTime cuando) {
    return _outbox.enqueue(
      type: SyncOp.mediaTag,
      targetId: assetId,
      payload: {'tags': tags.map((t) => t.json).toList()},
      occurredAt: cuando,
    );
  }

  /// Sube o baja el nivel de una foto.
  ///
  /// **La única escritura de esta app que no pasa por la bandeja.** Publicar es
  /// una decisión deliberada: encolarla haría que se ejecute sola horas después,
  /// cuando quien la tomó ya no está mirando. Sin red falla y se dice.
  ///
  /// El servidor manda: si rechaza el salto de escalón, la fila local no se
  /// toca.
  Future<void> cambiarVisibilidad(String assetId, String visibility) async {
    final asset = await _media.mediaSetVisibility(
      id: assetId,
      body: SetVisibilityDto(visibility: SetVisibilityDtoVisibility.values
          .firstWhere((v) => v.json == visibility)),
    );
    await (_db.update(_db.mediaAssets)..where((m) => m.id.equals(assetId)))
        .write(MediaAssetsCompanion(
      visibility: Value(asset.visibility.json ?? visibility),
      exifStrippedAt: Value(asset.exifStrippedAt),
      updatedAt: Value(asset.updatedAt),
      syncStatus: const Value(SyncStatus.synced),
    ));
  }

  /// Dónde ver una foto que ya no está en este teléfono.
  ///
  /// El bucket no es público (ADR-0010): se sirve con URL firmada y de vida
  /// corta, así que esto exige red. Es el caso de toda foto que tomó otro —
  /// baja del pull sin su binario.
  Future<String> urlParaVer(String assetId) async {
    final firmada = await _media.mediaDownloadUrl(id: assetId);
    return firmada.url;
  }

  /// Libera espacio sin perder nada que no esté a salvo en el servidor.
  ///
  /// El tope es de disco y no de calendario: una cuadrilla que toma 200 fotos en
  /// dos días ocupa lo mismo que otra en dos meses. Nunca borra lo que no subió
  /// —es la única copia— ni lo que falló, que sería descartar el trabajo del día
  /// en silencio.
  Future<int> limpiarPorEspacio({int topeBytes = topeDeFotosBytes}) async {
    final subidas = await (_db.select(_db.pendingUploads)
          ..where((p) => p.uploadedAt.isNotNull())
          ..orderBy([(p) => OrderingTerm.desc(p.uploadedAt)]))
        .get();

    var acumulado = 0;
    var borradas = 0;
    for (final fila in subidas) {
      acumulado += fila.bytes;
      if (acumulado <= topeBytes) continue;

      final archivo = File(fila.filePath);
      if (archivo.existsSync()) archivo.deleteSync();
      await (_db.delete(_db.pendingUploads)
            ..where((p) => p.assetId.equals(fila.assetId)))
          .go();
      borradas++;
    }
    return borradas;
  }

  static List<MediaTag> _leerTags(String json) {
    final crudas = (jsonDecode(json) as List).cast<String>();
    return crudas
        .map((t) => MediaTag.values.where((v) => v.json == t).firstOrNull)
        .nonNulls
        .toList();
  }

  /// Lo que espera subir su binario, más viejo primero.
  Future<List<PendingUpload>> pendingUploads() {
    return (_db.select(_db.pendingUploads)
          ..where((p) => p.uploadedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.assetId)]))
        .get();
  }

  /// El binario llegó: la fila se marca y el archivo local ya no hace falta.
  /// El binario llegó: se marca la subida **y el asset**.
  ///
  /// Sin lo segundo la galería sigue diciendo "guardada en el teléfono" hasta
  /// que un pull posterior traiga el estado — y ese pull no llega solo, porque
  /// nada vuelve a encolarse. La foto quedaba con cara de no haber subido.
  Future<void> markUploaded(String assetId) async {
    await _db.transaction(() async {
      await (_db.update(_db.pendingUploads)
            ..where((p) => p.assetId.equals(assetId)))
          .write(PendingUploadsCompanion(uploadedAt: Value(DateTime.now())));
      await (_db.update(_db.mediaAssets)..where((m) => m.id.equals(assetId)))
          .write(const MediaAssetsCompanion(uploadStatus: Value('READY')));
    });
  }

  Future<void> incrementAttempts(String assetId) async {
    await _db.customUpdate(
      'UPDATE pending_uploads SET attempts = attempts + 1 WHERE asset_id = ?',
      variables: [Variable<String>(assetId)],
      updates: {_db.pendingUploads},
    );
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxProvider),
    ref.watch(uuidProvider),
    ref.watch(mediaClientProvider),
  );
});
