import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/core/location/device_location.dart';
import 'package:snapline/core/media/photo_capture.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/media_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/features/today/evidence_collector.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// La escalera de evidencia completa: la ubicación es la prueba, la foto es lo
/// que queda sin ubicación, y sin ninguna de las dos **se marca igual**.
class _Gps implements DeviceLocation {
  const _Gps(this.resultado);
  final LocationResult resultado;
  @override
  Future<LocationResult> current() async => resultado;
}

class _Camara implements PhotoCapture {
  _Camara(this.ruta);
  final String? ruta;
  var llamada = false;
  @override
  Future<String?> takePhoto() async {
    llamada = true;
    return ruta;
  }
}

void main() {
  late AppDatabase db;
  late Outbox outbox;
  late MediaRepository media;
  late Directory dir;

  setUp(() {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
    media = MediaRepository(db, outbox, const Uuid());
    dir = Directory.systemTemp.createTempSync('snapline_foto');
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  File unaFoto() {
    final f = File('${dir.path}/frente-de-obra.jpg');
    f.writeAsBytesSync(List.generate(64, (i) => i));
    return f;
  }

  test('con GPS no se pide nada más: ni cámara ni foto', () async {
    final camara = _Camara(null);
    final collector = EvidenceCollector(
      const _Gps(LocationResult.ok(9.9281, -84.0907, isMocked: true)),
      camara,
      media,
    );

    final capturada = await collector.collect(projectId: 'p1');

    expect(camara.llamada, isFalse, reason: 'el primer escalón alcanzó');
    expect(capturada.conUbicacion, isTrue);
    expect(capturada.evidence.lat, 9.9281);
    // El isMocked viaja: regla 11.
    expect(capturada.evidence.isMockLocation, isTrue);
    expect(capturada.evidence.photoId, isNull);
  });

  test('sin GPS se pide la foto, y el registro queda encolado con su binario pendiente', () async {
    final foto = unaFoto();
    final collector = EvidenceCollector(
      const _Gps(LocationResult.failed(LocationFailure.denied)),
      _Camara(foto.path),
      media,
    );

    final capturada = await collector.collect(projectId: 'p1');

    expect(capturada.conFoto, isTrue);
    expect(capturada.evidence.photoId, isNotNull);

    // El registro viaja por la bandeja, con checksum para desduplicar (regla 19).
    final ops = await outbox.pending();
    final registro = ops.singleWhere((o) => o.type == SyncOp.mediaRegister);
    final payload = jsonDecode(registro.payload) as Map<String, Object?>;
    expect(payload['id'], capturada.evidence.photoId);
    expect(payload['projectId'], 'p1');
    expect(payload['checksum'], isNotEmpty);
    expect(payload['kind'], 'PHOTO');

    // Y el binario espera su subida.
    final pendientes = await media.pendingUploads();
    expect(pendientes.single.assetId, capturada.evidence.photoId);
    expect(pendientes.single.filePath, foto.path);
  });

  test('cámara cancelada o sin permiso: se marca igual, sin nada (regla 9)', () async {
    final camara = _Camara(null);
    final collector = EvidenceCollector(
      const _Gps(LocationResult.failed(LocationFailure.timeout)),
      camara,
      media,
    );

    final capturada = await collector.collect(projectId: 'p1');

    expect(camara.llamada, isTrue, reason: 'el segundo escalón se ofreció');
    expect(capturada.conUbicacion, isFalse);
    expect(capturada.conFoto, isFalse);
    expect(capturada.evidence.photoId, isNull);
    // La escalera decide qué se pide, nunca qué se permite: el que llama marca
    // con esta evidencia vacía y el servidor pone las dos banderas.
  });
}
