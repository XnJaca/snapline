import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/check_invite_dto.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/session/session_controller.dart';

/// El canje va en dos pasos: primero se comprueba el código, después se pide la
/// contraseña. Escribirla y recién ahí enterarse de que el código no servía es
/// hacerle perder el trabajo a quien recién entra.
enum RedeemStep { code, password }

class RedeemState {
  const RedeemState({
    this.step = RedeemStep.code,
    this.identifier = '',
    this.code = '',
    this.busy = false,
    this.failure,
  });

  final RedeemStep step;
  final String identifier;
  final String code;
  final bool busy;
  final ApiFailure? failure;

  RedeemState copyWith({
    RedeemStep? step,
    String? identifier,
    String? code,
    bool? busy,
    ApiFailure? failure,
    bool limpiarError = false,
  }) => RedeemState(
    step: step ?? this.step,
    identifier: identifier ?? this.identifier,
    code: code ?? this.code,
    busy: busy ?? this.busy,
    failure: limpiarError ? null : (failure ?? this.failure),
  );
}

class RedeemController extends Notifier<RedeemState> {
  @override
  RedeemState build() => const RedeemState();

  /// Comprueba el código sin consumirlo. Si la persona ya tiene contraseña
  /// —trabaja para otro contratista— no hay segundo paso: entra directo.
  Future<void> verify({required String identifier, required String code}) async {
    state = state.copyWith(busy: true, limpiarError: true);
    try {
      final check = await ref
          .read(authClientProvider)
          .authVerifyInvite(
            body: CheckInviteDto(identifier: identifier.trim(), code: code.trim()),
          );

      if (check.needsPassword) {
        state = state.copyWith(
          step: RedeemStep.password,
          identifier: identifier.trim(),
          code: code.trim(),
          busy: false,
        );
        return;
      }

      await ref
          .read(sessionControllerProvider.notifier)
          .redeemInvite(identifier: identifier.trim(), code: code.trim());
      state = state.copyWith(busy: false);
    } catch (error) {
      state = state.copyWith(busy: false, failure: ApiFailure.from(error));
    }
  }

  Future<void> submitPassword(String password) async {
    state = state.copyWith(busy: true, limpiarError: true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .redeemInvite(
            identifier: state.identifier,
            code: state.code,
            password: password,
          );
      state = state.copyWith(busy: false);
    } catch (error) {
      state = state.copyWith(busy: false, failure: ApiFailure.from(error));
    }
  }

  /// Volver al código: si venció entre un paso y el otro, se pide otro y se
  /// escribe de nuevo sin salir de la pantalla.
  void backToCode() => state = state.copyWith(
    step: RedeemStep.code,
    limpiarError: true,
  );

  void clearError() {
    if (state.failure != null) state = state.copyWith(limpiarError: true);
  }
}

final redeemControllerProvider =
    NotifierProvider<RedeemController, RedeemState>(RedeemController.new);
