import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/media_client.dart';
import 'package:snapline/api/models/media_asset.dart';
import 'package:snapline/api/models/signed_url_dto.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/media_repository.dart';
import 'package:snapline/data/sync/media_uploader.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// La subida del binario: pedir la URL, mandar, confirmar — y cada fallo deja
/// la foto esperando el próximo intento, nunca perdida.
class _MediaApi implements MediaClient {
  _MediaApi({this.urlFalla, this.yaSubido = false});

  final bool? urlFalla;
  final bool yaSubido;
  final confirmados = <String>[];

  @override
  Future<SignedUrlDto> mediaUploadUrl({required String id}) async {
    if (yaSubido) {
      throw DioException(
        requestOptions: RequestOptions(path: '/media/$id/upload-url'),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 409,
          data: {'code': 'MEDIA_ALREADY_UPLOADED'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    if (urlFalla == true) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      );
    }
    return const SignedUrlDto(url: 'https://firmada.example/put', expiresInSeconds: 900);
  }

  @override
  Future<MediaAsset> mediaMarkUploaded({required String id}) async {
    confirmados.add(id);
    return MediaAsset.fromJson(const {
      'id': 'a', 'companyId': 'c', 'projectId': 'p', 'kind': 'PHOTO',
      'storageKey': 'k', 'mime': 'image/jpeg', 'bytes': null, 'width': null,
      'height': null, 'capturedAt': null, 'uploadedByMembershipId': 'm',
      'deviceLat': null, 'deviceLng': null, 'checksum': 'x',
      'uploadStatus': 'READY', 'visibility': 'INTERNAL', 'exifStrippedAt': null,
      'documentKind': null, 'deletedAt': null,
      'createdAt': '2026-08-11T00:00:00Z', 'updatedAt': '2026-08-11T00:00:00Z',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late MediaRepository media;
  late Directory dir;

  setUp(() {
    db = testDatabase();
    media = MediaRepository(db, Outbox(db, const Uuid()), const Uuid(), MediaClientNulo());
    dir = Directory.systemTemp.createTempSync('snapline_subida');
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<String> unaFotoRegistrada() async {
    final f = File('${dir.path}/obra.jpg')..writeAsBytesSync([1, 2, 3, 4]);
    return media.registerPhoto(projectId: 'p1', filePath: f.path);
  }

  test('sube, confirma y marca — el archivo deja de estar pendiente', () async {
    final id = await unaFotoRegistrada();
    final api = _MediaApi();
    final enviados = <String>[];

    final subidos = await MediaUploader(media, api, (url, bytes, mime) async {
      enviados.add(url);
      expect(bytes, hasLength(4));
      expect(mime, 'image/jpeg');
    }).subirPendientes();

    expect(subidos, 1);
    expect(enviados.single, contains('firmada'));
    expect(api.confirmados.single, id);
    expect(await media.pendingUploads(), isEmpty);
  });

  test('MEDIA_ALREADY_UPLOADED es éxito: se deja de reintentar', () async {
    await unaFotoRegistrada();
    final api = _MediaApi(yaSubido: true);

    final subidos = await MediaUploader(media, api, (u, b, m) async {
      fail('con el guard del servidor no hay nada que mandar');
    }).subirPendientes();

    expect(subidos, 1);
    expect(await media.pendingUploads(), isEmpty);
  });

  test('un fallo deja la foto esperando, con su contador — nunca perdida', () async {
    await unaFotoRegistrada();
    final api = _MediaApi(urlFalla: true);

    final subidos = await MediaUploader(media, api, (u, b, m) async {})
        .subirPendientes();

    expect(subidos, 0);
    final pendientes = await media.pendingUploads();
    expect(pendientes, hasLength(1));
    expect(pendientes.single.attempts, 1);
  });
}
