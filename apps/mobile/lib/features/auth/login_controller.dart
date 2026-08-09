import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/session/session_controller.dart';

/// Estado del envío del formulario de login.
///
/// Es distinto del estado de sesión a propósito: un intento fallido deja el
/// error acá y no toca la sesión guardada.
class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required String identifier,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(identifier: identifier.trim(), password: password);
      state = const AsyncData(null);
      return true;
    } on ApiFailure catch (failure, stack) {
      state = AsyncError(failure, stack);
      return false;
    }
  }

  void clearError() {
    if (state is AsyncError) state = const AsyncData(null);
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);
