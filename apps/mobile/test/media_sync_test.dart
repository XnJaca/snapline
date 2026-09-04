import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/sync_client.dart';
import 'package:snapline/api/models/media_asset_dto.dart';
import 'package:snapline/api/models/media_asset_dto_kind.dart';
import 'package:snapline/api/models/media_asset_dto_tags.dart';
import 'package:snapline/api/models/media_asset_dto_upload_status.dart';
import 'package:snapline/api/models/media_asset_dto_visibility.dart';
import 'package:snapline/api/models/sync_pull_response_dto.dart';
import 'package:snapline/api/models/sync_push_dto.dart';
import 'package:snapline/api/models/sync_push_response_dto.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/synchronizer.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// Qué pasa con una foto local cuando el servidor manda la suya.
///
/// El caso que se vio en el teléfono: se etiquetó una foto, el pull la trajo
/// sin etiquetas —porque el push todavía no había entrado— y la pisó. La
/// etiqueta desaparecía de la pantalla sin que nadie la hubiera quitado.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> sembrarLocal(String id, {
    required List<String> tags,
    required SyncStatus estado,
  }) async {
    await db.into(db.mediaAssets).insert(
      MediaAssetsCompanion.insert(
        id: id,
        companyId: 'co1',
        updatedAt: DateTime(2026, 8, 12),
        projectId: 'p1',
        kind: 'PHOTO',
        mime: 'image/jpeg',
        visibility: 'INTERNAL',
        uploadStatus: 'READY',
        tags: Value(jsonEncode(tags)),
        syncStatus: Value(estado),
      ),
    );
  }

  Future<void> sincronizarCon(MediaAssetDto delServidor) async {
    final sync = Synchronizer(
      db,
      _ClienteQueDevuelve(delServidor),
      Outbox(db, const Uuid()),
    );
    await sync.sync();
  }

  MediaAssetDto delServidor(String id, {List<MediaAssetDtoTags> tags = const []}) {
    return MediaAssetDto(
      id: id,
      companyId: 'co1',
      createdAt: DateTime(2026, 8, 12),
      updatedAt: DateTime(2026, 8, 12, 10),
      deletedAt: null,
      projectId: 'p1',
      kind: MediaAssetDtoKind.photo,
      documentKind: null,
      storageKey: 'co1/p1/$id.jpg',
      mime: 'image/jpeg',
      bytes: 100,
      width: null,
      height: null,
      capturedAt: DateTime(2026, 8, 12),
      uploadedByMembershipId: null,
      deviceLat: null,
      deviceLng: null,
      checksum: 'sum',
      uploadStatus: MediaAssetDtoUploadStatus.ready,
      visibility: MediaAssetDtoVisibility.internal,
      exifStrippedAt: null,
      tags: tags,
    );
  }

  test('el pull no pisa una foto con cambios sin empujar', () async {
    await sembrarLocal('a1', tags: ['BEFORE'], estado: SyncStatus.pending);

    await sincronizarCon(delServidor('a1'));

    final fila = await (db.select(db.mediaAssets)
          ..where((m) => m.id.equals('a1')))
        .getSingle();
    expect(jsonDecode(fila.tags), ['BEFORE'],
        reason: 'la etiqueta local todavía no llegó al servidor');
  });

  test('sí pisa la que ya estaba sincronizada', () async {
    await sembrarLocal('a1', tags: ['BEFORE'], estado: SyncStatus.synced);

    await sincronizarCon(delServidor('a1', tags: [MediaAssetDtoTags.after]));

    final fila = await (db.select(db.mediaAssets)
          ..where((m) => m.id.equals('a1')))
        .getSingle();
    expect(jsonDecode(fila.tags), ['AFTER'],
        reason: 'sin nada pendiente, manda el servidor');
  });
}

class _ClienteQueDevuelve implements SyncClient {
  _ClienteQueDevuelve(this.asset);

  final MediaAssetDto asset;

  @override
  Future<SyncPullResponseDto> syncPull({String? since}) async =>
      SyncPullResponseDto(
        serverTime: DateTime.utc(2026, 8, 12),
        customers: const [],
        sites: const [],
        projects: const [],
        assignments: const [],
        mediaAssets: [asset],
        timeEntries: const [],
        crews: const [],
        crewMembers: const [],
        projectStatusChanges: const [],
        projectUpdates: const [],
        people: const [],
        deleted: const {},
      );

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async =>
      SyncPushResponseDto(failed: 0, results: const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
