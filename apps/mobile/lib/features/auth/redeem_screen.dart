import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/snapline_backdrop.dart';
import '../../core/brand/snapline_logo.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'redeem_controller.dart';

/// La puerta de entrada de alguien nuevo, en dos pasos: primero el código, y
/// una vez comprobado, la contraseña.
///
/// **Es la única acción del producto que se bloquea sin red, y está bien que lo
/// haga**: no hay nada que encolar —sin canje no hay sesión ni bandeja— y
/// guardar credenciales para mandarlas después sería dejarlas en el teléfono.
class RedeemScreen extends ConsumerStatefulWidget {
  const RedeemScreen({super.key});

  static const route = '/redeem';

  @override
  ConsumerState<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends ConsumerState<RedeemScreen> {
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_codeFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(redeemControllerProvider.notifier)
        .verify(identifier: _identifier.text, code: _code.text);
  }

  Future<void> _submitPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(redeemControllerProvider.notifier).submitPassword(_password.text);
    // La navegación la decide el router al cambiar la sesión, no esta pantalla.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = ref.watch(redeemControllerProvider);

    return Scaffold(
      body: SnaplineBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: state.step == RedeemStep.code
                    ? _pasoCodigo(l10n, spacing, state)
                    : _pasoContrasena(l10n, spacing, state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoCodigo(AppLocalizations l10n, dynamic spacing, RedeemState state) {
    return Form(
      key: _codeFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SnaplineLogoStacked()),
          SizedBox(height: spacing.xxl),

          _encabezado(l10n.authRedeemTitle, l10n.authRedeemIntro, spacing),
          SizedBox(height: spacing.xl),

          TextFormField(
            controller: _identifier,
            enabled: !state.busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.authLoginIdentifierLabel,
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? l10n.authLoginIdentifierRequired
                : null,
            onChanged: _limpiar,
          ),
          SizedBox(height: spacing.lg),

          TextFormField(
            controller: _code,
            enabled: !state.busy,
            keyboardType: TextInputType.number,
            // Se dicta en voz alta y se escribe con guantes: solo dígitos y
            // teclado numérico.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => state.busy ? null : _verify(),
            decoration: InputDecoration(labelText: l10n.authRedeemCodeLabel),
            validator: (value) {
              final code = value?.trim() ?? '';
              if (code.isEmpty) return l10n.authRedeemCodeRequired;
              if (code.length != 6) return l10n.authRedeemCodeLength;
              return null;
            },
            onChanged: _limpiar,
          ),
          SizedBox(height: spacing.xl),

          _accion(l10n.authRedeemContinue, state.busy, _verify, spacing),
          ..._error(state, l10n, spacing),

          SizedBox(height: spacing.lg),
          TextButton(
            onPressed: state.busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.authRedeemBackToLogin),
          ),
        ],
      ),
    );
  }

  Widget _pasoContrasena(
    AppLocalizations l10n,
    dynamic spacing,
    RedeemState state,
  ) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SnaplineLogoStacked()),
          SizedBox(height: spacing.xxl),

          _encabezado(
            l10n.authRedeemPasswordTitle,
            l10n.authRedeemPasswordIntro,
            spacing,
          ),
          SizedBox(height: spacing.xl),

          TextFormField(
            controller: _password,
            enabled: !state.busy,
            obscureText: !_passwordVisible,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => state.busy ? null : _submitPassword(),
            decoration: InputDecoration(
              labelText: l10n.authRedeemPasswordLabel,
              helperText: l10n.authRedeemPasswordHint,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                tooltip: _passwordVisible
                    ? l10n.authLoginHidePassword
                    : l10n.authLoginShowPassword,
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            validator: (value) {
              final clave = value ?? '';
              if (clave.isEmpty) return l10n.authRedeemPasswordRequired;
              if (clave.length < 8) return l10n.authRedeemPasswordShort;
              return null;
            },
            onChanged: _limpiar,
          ),
          SizedBox(height: spacing.xl),

          _accion(l10n.authRedeemSubmit, state.busy, _submitPassword, spacing),
          ..._error(state, l10n, spacing),

          SizedBox(height: spacing.lg),
          TextButton(
            // Si el código venció entre un paso y el otro, se vuelve acá sin
            // salir de la pantalla.
            onPressed: state.busy
                ? null
                : () => ref.read(redeemControllerProvider.notifier).backToCode(),
            child: Text(l10n.authRedeemChangeCode),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(String titulo, String texto, dynamic spacing) => Column(
    children: [
      Text(
        titulo,
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: spacing.sm),
      Text(
        texto,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    ],
  );

  /// El alto de 64dp lo pone el tema. Ver ADR-0009.
  Widget _accion(
    String label,
    bool busy,
    Future<void> Function() onTap,
    dynamic spacing,
  ) => FilledButton(
    onPressed: busy ? null : onTap,
    child: busy
        ? SizedBox.square(
            dimension: spacing.xl,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );

  List<Widget> _error(
    RedeemState state,
    AppLocalizations l10n,
    dynamic spacing,
  ) {
    final failure = state.failure;
    if (failure == null) return const [];
    return [
      SizedBox(height: spacing.lg),
      StatusChip(
        // Sin conexión no es culpa de quien está entrando: se avisa, no se acusa.
        tone: failure.isNoConnection ? StatusTone.warning : StatusTone.danger,
        label: _messageFor(failure, l10n),
        expand: true,
      ),
    ];
  }

  void _limpiar(String _) =>
      ref.read(redeemControllerProvider.notifier).clearError();

  /// Ramifica sobre el `code` estable y no sobre el status: un código vencido y
  /// uno equivocado son los dos un 401, y lo que hay que hacer con cada uno es
  /// lo contrario —pedir otro, o revisar los dígitos—.
  String _messageFor(ApiFailure failure, AppLocalizations l10n) {
    return switch (failure.code) {
      ApiErrorCode.inviteExpired => l10n.authRedeemErrorExpired,
      ApiErrorCode.inviteTooManyAttempts => l10n.authRedeemErrorTooMany,
      ApiErrorCode.inviteInvalid => l10n.authRedeemErrorInvalid,
      _ => switch (failure.kind) {
        ApiFailureKind.noConnection => l10n.authRedeemErrorNoConnection,
        ApiFailureKind.server => l10n.authRedeemErrorServer,
        ApiFailureKind.invalidCredentials => l10n.authRedeemErrorInvalid,
        ApiFailureKind.unknown => l10n.authRedeemErrorUnknown,
      },
    };
  }
}
