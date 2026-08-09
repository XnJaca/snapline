import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/core/network/api_failure.dart';

DioException _error(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response<void>(requestOptions: options, statusCode: status),
  );
}

void main() {
  // El criterio del spec: sin conexión y credenciales inválidas nunca se
  // confunden. Mandar a revisar la contraseña a alguien que solo está sin señal
  // es el error caro de esta pantalla.
  group('ApiFailure', () {
    test('un 401 es credenciales, no red', () {
      final failure = ApiFailure.from(
        _error(DioExceptionType.badResponse, status: 401),
      );
      expect(failure.kind, ApiFailureKind.invalidCredentials);
      expect(failure.isNoConnection, isFalse);
    });

    test('sin conexión no se confunde con credenciales', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = ApiFailure.from(_error(type));
        expect(
          failure.kind,
          ApiFailureKind.noConnection,
          reason: '$type debería leerse como falta de conexión',
        );
      }
    });

    test('un error sin respuesta se trata como falta de conexión', () {
      // Es el DNS que no resuelve: para el usuario, no hay internet.
      final failure = ApiFailure.from(_error(DioExceptionType.unknown));
      expect(failure.kind, ApiFailureKind.noConnection);
    });

    test('un 500 es problema del servidor, no del usuario', () {
      final failure = ApiFailure.from(
        _error(DioExceptionType.badResponse, status: 500),
      );
      expect(failure.kind, ApiFailureKind.server);
    });

    test('lo que no es DioException cae en desconocido', () {
      expect(
        ApiFailure.from(Exception('otra cosa')).kind,
        ApiFailureKind.unknown,
      );
    });
  });
}
