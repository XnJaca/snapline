import 'package:dio/dio.dart';

/// Por qué falló una llamada al API.
///
/// El spec exige que "sin conexión" y "credenciales inválidas" nunca se
/// confundan: son la misma pantalla roja para el usuario si no se distinguen, y
/// mandan a revisar la contraseña a alguien que solo está sin señal.
///
/// El texto que ve el usuario lo resuelve la UI con i18n; acá solo va el motivo.
enum ApiFailureKind { invalidCredentials, noConnection, server, unknown }

class ApiFailure implements Exception {
  const ApiFailure(this.kind);

  factory ApiFailure.from(Object error) {
    if (error is! DioException) return const ApiFailure(ApiFailureKind.unknown);

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
          return const ApiFailure(ApiFailureKind.invalidCredentials);
        }
        if (status >= 500) return const ApiFailure(ApiFailureKind.server);
        return const ApiFailure(ApiFailureKind.unknown);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // Sin respuesta y sin tipo reconocido: en la práctica es el DNS que no
        // resuelve, que para el usuario es no tener conexión.
        return error.response == null
            ? const ApiFailure(ApiFailureKind.noConnection)
            : const ApiFailure(ApiFailureKind.unknown);
    }
  }

  final ApiFailureKind kind;

  bool get isNoConnection => kind == ApiFailureKind.noConnection;

  @override
  String toString() => 'ApiFailure(${kind.name})';
}
