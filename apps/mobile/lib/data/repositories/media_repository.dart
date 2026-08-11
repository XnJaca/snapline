import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../sync/outbox.dart';

/// Registra fotos y deja el binario esperando su subida.
///
/// El registro viaja por la bandeja como cualquier mutación; el archivo pesa y
/// sube aparte, con reintento (regla 19: el checksum desduplica). Nada de esto
/// espera a la red.
class MediaRepository {
  const MediaRepository(this._db, this._outbox, this._uuid);

  final AppDatabase _db;
  final Outbox _outbox;
  final Uuid _uuid;

  /// Registra una foto tomada en el dispositivo y devuelve el id del asset.
  ///
  /// El id nace acá y es el definitivo (regla 18): el marcaje puede referirlo
  /// antes de que el servidor sepa que existe.
  Future<String> registerPhoto({
    required String projectId,
    required String filePath,
    String mime = 'image/jpeg',
    DateTime? capturedAt,
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
        ),
      );
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
        },
        occurredAt: cuando,
      );
    });

    return id;
  }

  /// Lo que espera subir su binario, más viejo primero.
  Future<List<PendingUpload>> pendingUploads() {
    return (_db.select(_db.pendingUploads)
          ..where((p) => p.uploadedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.assetId)]))
        .get();
  }

  /// El binario llegó: la fila se marca y el archivo local ya no hace falta.
  Future<void> markUploaded(String assetId) async {
    await (_db.update(_db.pendingUploads)
          ..where((p) => p.assetId.equals(assetId)))
        .write(PendingUploadsCompanion(uploadedAt: Value(DateTime.now())));
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
  );
});
