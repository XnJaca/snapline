import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/clients/auth_client.dart';
import '../session/session_controller.dart';
import 'auth_interceptor.dart';

/// Base del API. Se pasa en build con `--dart-define=API_BASE_URL=...`.
///
/// El emulador de Android no ve `localhost` del host: ahí va `10.0.2.2`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',
);

BaseOptions _options() => BaseOptions(
  baseUrl: apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 20),
  // El interceptor necesita ver el 401 como error, no como respuesta válida.
  validateStatus: (status) => status != null && status < 400,
);

/// Dio sin interceptores. Lo usa el refresh y el reintento, que no pueden
/// volver a entrar al interceptor de auth.
final bareDioProvider = Provider<Dio>((ref) => Dio(_options()));

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_options());
  dio.interceptors.add(
    AuthInterceptor(
      bare: ref.watch(bareDioProvider),
      readSession: () => ref.read(sessionControllerProvider).value,
      onRenewed: (session) =>
          ref.read(sessionControllerProvider.notifier).renew(session),
    ),
  );
  return dio;
});

/// Cliente de auth sin token: login y refresh son públicos, y usarlos con el
/// Dio interceptado dispararía un refresh en el propio login fallido.
final authClientProvider = Provider<AuthClient>((ref) {
  return AuthClient(ref.watch(bareDioProvider));
});
