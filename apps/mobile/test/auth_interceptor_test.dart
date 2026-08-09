import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/core/network/auth_interceptor.dart';
import 'package:snapline/core/session/session.dart';

import 'support/fakes.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions) responder;
  final List<String> llamadas = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    llamadas.add(options.path);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, Object?> _authResult(String token) => {
  'accessToken': token,
  'refreshToken': 'refresh-nuevo',
  'expiresInSeconds': 3600,
  'user': {
    'id': 'u1',
    'name': 'Carlos',
    'locale': 'es',
    'email': null,
    'phone': '+15551234567',
  },
  'membership': {
    'id': 'm1',
    'companyId': 'c1',
    'companyName': 'PC LLC',
    'role': 'WORKER',
    'permissions': ['time.clock', 'media.capture'],
  },
  'memberships': const [],
};

void main() {
  late _FakeAdapter adapter;
  late Dio bare;
  late Dio dio;
  late Session session;
  Session? renovada;

  void montar(FutureOr<ResponseBody> Function(RequestOptions) responder) {
    adapter = _FakeAdapter(responder);
    bare = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    dio = Dio(
        BaseOptions(
          baseUrl: 'http://test',
          validateStatus: (s) => s != null && s < 400,
        ),
      )
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          bare: bare,
          readSession: () => session,
          onRenewed: (s) async => renovada = s,
        ),
      );
  }

  setUp(() {
    session = buildSession();
    renovada = null;
  });

  test('pone el token en cada petición', () async {
    String? enviado;
    montar((options) {
      enviado = options.headers['Authorization'] as String?;
      return _json({'ok': true}, 200);
    });

    await dio.get<dynamic>('/projects');
    expect(enviado, 'Bearer ${session.accessToken}');
  });

  // El criterio del spec: un 401 a mitad de sesión no interrumpe al usuario.
  test('un 401 dispara el refresh y reintenta la petición una vez', () async {
    var intentos = 0;
    montar((options) {
      if (options.path.contains('/auth/refresh')) {
        return _json(_authResult('access-nuevo'), 200);
      }
      intentos++;
      return intentos == 1
          ? _json({'message': 'expirado'}, 401)
          : _json({'ok': true}, 200);
    });

    final response = await dio.get<dynamic>('/projects');

    expect(response.statusCode, 200);
    expect(intentos, 2, reason: 'la original y el reintento');
    expect(adapter.llamadas, contains('/auth/refresh'));
    expect(renovada?.accessToken, 'access-nuevo');
  });

  test('reintenta una sola vez: un 401 tras renovar no hace bucle', () async {
    var refrescos = 0;
    montar((options) {
      if (options.path.contains('/auth/refresh')) {
        refrescos++;
        return _json(_authResult('access-nuevo'), 200);
      }
      return _json({'message': 'expirado'}, 401);
    });

    await expectLater(
      dio.get<dynamic>('/projects'),
      throwsA(isA<DioException>()),
    );
    expect(refrescos, 1);
  });

  // Un trabajador sin cobertura tiene que poder seguir capturando aunque su
  // token esté vencido: si el refresh falla, la sesión NO se toca.
  test('si el refresh falla no borra ni renueva la sesión', () async {
    montar((options) {
      if (options.path.contains('/auth/refresh')) {
        return _json({'message': 'refresh vencido'}, 401);
      }
      return _json({'message': 'expirado'}, 401);
    });

    await expectLater(
      dio.get<dynamic>('/projects'),
      throwsA(isA<DioException>()),
    );
    expect(renovada, isNull);
  });

  test('varias peticiones en paralelo comparten un solo refresh', () async {
    var refrescos = 0;
    final vistos = <String>{};
    montar((options) {
      if (options.path.contains('/auth/refresh')) {
        refrescos++;
        return _json(_authResult('access-nuevo'), 200);
      }
      if (vistos.add(options.path)) return _json({'message': 'x'}, 401);
      return _json({'ok': true}, 200);
    });

    await Future.wait([
      dio.get<dynamic>('/projects'),
      dio.get<dynamic>('/media'),
      dio.get<dynamic>('/time-entries'),
    ]);

    expect(
      refrescos,
      1,
      reason: 'tres refresh en paralelo rotarían el token tres veces',
    );
  });
}
