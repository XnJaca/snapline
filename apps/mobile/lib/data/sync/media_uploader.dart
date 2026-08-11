import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/clients/media_client.dart';
import '../../core/network/api_client.dart';
import '../repositories/media_repository.dart';

/// Manda el binario a la URL firmada. Inyectable para que los tests no
/// necesiten un bucket.
typedef BinarySender =
    Future<void> Function(String url, List<int> bytes, String mime);

/// Sube los binarios que el registro dejó esperando.
///
/// El camino del reintento offline: `media.register` entró por la bandeja sin
/// poder devolver dónde subir, así que acá se pide la URL, se sube, y se
/// confirma. Cada paso puede fallar sin arrastrar a los demás pendientes.
class MediaUploader {
  const MediaUploader(this._media, this._api, this._send);

  final MediaRepository _media;
  final MediaClient _api;
  final BinarySender _send;

  /// Devuelve cuántos subió. Nunca lanza: una foto que no pudo subir queda
  /// esperando el próximo intento, con su contador.
  Future<int> subirPendientes() async {
    var subidos = 0;
    for (final pendiente in await _media.pendingUploads()) {
      try {
        final destino = await _api.mediaUploadUrl(id: pendiente.assetId);
        final bytes = await File(pendiente.filePath).readAsBytes();
        await _send(destino.url, bytes, pendiente.mime);
        await _api.mediaMarkUploaded(id: pendiente.assetId);
        await _media.markUploaded(pendiente.assetId);
        subidos++;
      } on DioException catch (e) {
        // "Ya subido" es éxito: un reintento anterior llegó y la confirmación
        // se perdió en el camino. Se deja de reintentar. El código viene en el
        // envelope de ADR-0011.
        final data = e.response?.data;
        final code = data is Map ? data['code'] : null;
        if (code == 'MEDIA_ALREADY_UPLOADED') {
          await _media.markUploaded(pendiente.assetId);
          subidos++;
          continue;
        }
        await _media.incrementAttempts(pendiente.assetId);
        developer.log(
          'subida falló para ${pendiente.assetId}: $code',
          name: 'media',
        );
      } catch (e) {
        await _media.incrementAttempts(pendiente.assetId);
        developer.log('subida falló para ${pendiente.assetId}', name: 'media', error: e);
      }
    }
    return subidos;
  }
}

final mediaUploaderProvider = Provider<MediaUploader>((ref) {
  final bare = ref.watch(bareDioProvider);
  return MediaUploader(
    ref.watch(mediaRepositoryProvider),
    ref.watch(mediaClientProvider),
    // La URL firmada ya lleva su permiso adentro: va con el dio pelado, sin
    // interceptor — el Authorization nuestro rompería la firma de S3.
    (url, bytes, mime) => bare.put<void>(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Type': mime, 'Content-Length': bytes.length},
      ),
    ),
  );
});
