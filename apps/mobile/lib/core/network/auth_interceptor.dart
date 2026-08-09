import 'package:dio/dio.dart';

import '../../api/models/auth_result_dto.dart';
import '../../api/models/refresh_dto.dart';
import '../session/session.dart';

/// Pone el token en cada petición y renueva cuando vence.
///
/// Un `401` no expulsa a nadie: intenta refrescar y **reintenta la petición
/// original una sola vez**. Si el refresh también falla, deja pasar el error sin
/// borrar la sesión — un trabajador sin cobertura tiene que poder seguir
/// capturando aunque su token esté vencido. Ver SPEC-0001.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.readSession,
    required this.onRenewed,
    required Dio bare,
  }) : _bare = bare;

  /// Dio sin interceptores: refrescar y reintentar no pueden volver a entrar acá.
  final Dio _bare;

  final Session? Function() readSession;
  final Future<void> Function(Session) onRenewed;

  /// Varias peticiones en paralelo con el token vencido comparten un solo
  /// refresh; sin esto se dispara uno por petición y el servidor rota el token
  /// varias veces.
  Future<AuthResultDto>? _inFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = readSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final session = readSession();

    final noValeReintentar =
        err.response?.statusCode != 401 ||
        session == null ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.extra['snapline.retried'] == true;

    if (noValeReintentar) return handler.next(err);

    try {
      final renewed = await (_inFlight ??= _refresh(session.refreshToken));

      final updated = Session.fromAuthResult(renewed, DateTime.now());
      await onRenewed(updated);

      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${updated.accessToken}'
        ..extra['snapline.retried'] = true;

      handler.resolve(await _bare.fetch<dynamic>(options));
    } on DioException catch (fallo) {
      // Cuál error se propaga importa: el original es SIEMPRE un 401, porque es
      // lo que entra a esta rama. Si el refresh falló por falta de señal y se
      // reenvía el 401, aguas arriba se lee como credenciales inválidas y se
      // manda a revisar la contraseña a alguien que solo está sin cobertura —
      // justo lo que este interceptor existe para evitar.
      final esCredenciales = fallo.response?.statusCode == 401;
      handler.next(esCredenciales ? err : fallo);
    } catch (_) {
      handler.next(err);
    } finally {
      // La sesión NO se borra en ningún caso: sin ella el trabajador no puede
      // seguir capturando.
      _inFlight = null;
    }
  }

  Future<AuthResultDto> _refresh(String refreshToken) async {
    final response = await _bare.post<Map<String, Object?>>(
      '/auth/refresh',
      data: RefreshDto(refreshToken: refreshToken).toJson(),
    );
    return AuthResultDto.fromJson(response.data!);
  }
}
