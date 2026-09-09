import 'package:dio/dio.dart';

/// Por qué falló una llamada al API.
///
/// El spec exige que "sin conexión" y "credenciales inválidas" nunca se
/// confundan: son la misma pantalla roja para el usuario si no se distinguen, y
/// mandan a revisar la contraseña a alguien que solo está sin señal.
///
/// El texto que ve el usuario lo resuelve la UI con i18n; acá solo va el motivo.
enum ApiFailureKind { invalidCredentials, noConnection, server, unknown }

/// Los códigos estables del envelope que la app necesita distinguir (ADR-0011).
///
/// Sin esto, canjear un código vencido y equivocarse de código son el mismo 401
/// en pantalla, y la salida de cada uno es opuesta: pedir otro código, o volver
/// a intentar el que se tiene.
abstract final class ApiErrorCode {
  static const inviteInvalid = 'INVITE_CODE_INVALID';
  static const inviteExpired = 'INVITE_CODE_EXPIRED';
  static const inviteTooManyAttempts = 'INVITE_TOO_MANY_ATTEMPTS';
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, {this.code});

  factory ApiFailure.from(Object error) {
    if (error is! DioException) return const ApiFailure(ApiFailureKind.unknown);

    final code = _codeOf(error.response?.data);

    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiFailure(ApiFailureKind.noConnection);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401 || status == 403) {
          return ApiFailure(ApiFailureKind.invalidCredentials, code: code);
        }
        if (status >= 500) return ApiFailure(ApiFailureKind.server, code: code);
        return ApiFailure(ApiFailureKind.unknown, code: code);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // Sin respuesta y sin tipo reconocido: en la práctica es el DNS que no
        // resuelve, que para el usuario es no tener conexión.
        return error.response == null
            ? const ApiFailure(ApiFailureKind.noConnection)
            : ApiFailure(ApiFailureKind.unknown, code: code);
    }
  }

  final ApiFailureKind kind;

  /// El `code` del envelope, cuando el servidor lo mandó. Es estable y no se
  /// traduce: la app ramifica sobre esto y nunca sobre el mensaje.
  final String? code;

  bool get isNoConnection => kind == ApiFailureKind.noConnection;

  @override
  String toString() => 'ApiFailure(${kind.name}${code == null ? '' : ', $code'})';
}

/// El cuerpo del error llega como mapa cuando el servidor respondió con su
/// envelope; cualquier otra cosa —HTML de un proxy, texto suelto— no lo tiene.
String? _codeOf(Object? data) {
  if (data is! Map) return null;
  final code = data['code'];
  return code is String && code.isNotEmpty ? code : null;
}
