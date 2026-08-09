import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/snapline_backdrop.dart';
import '../../core/brand/snapline_logo.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'login_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .submit(identifier: _identifier.text, password: _password.text);
    // La navegación la decide el router al cambiar la sesión, no esta pantalla.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final state = ref.watch(loginControllerProvider);
    final enviando = state.isLoading;

    return Scaffold(
      body: SnaplineBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: SnaplineLogoStacked()),
                    SizedBox(height: spacing.xxl * 1.5),

                    TextFormField(
                      controller: _identifier,
                      enabled: !enviando,
                      // El servidor resuelve contra email o teléfono, así que la
                      // app no adivina de qué tipo es lo que se escribió.
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.telephoneNumber,
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authLoginIdentifierLabel,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.authLoginIdentifierRequired
                          : null,
                      onChanged: (_) =>
                          ref.read(loginControllerProvider.notifier).clearError(),
                    ),
                    SizedBox(height: spacing.lg),

                    TextFormField(
                      controller: _password,
                      enabled: !enviando,
                      obscureText: !_passwordVisible,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => enviando ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.authLoginPasswordLabel,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          tooltip: _passwordVisible
                              ? l10n.authLoginHidePassword
                              : l10n.authLoginShowPassword,
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? l10n.authLoginPasswordRequired
                          : null,
                      onChanged: (_) =>
                          ref.read(loginControllerProvider.notifier).clearError(),
                    ),
                    SizedBox(height: spacing.xl),

                    // El alto de 64dp lo pone el tema. Ver ADR-0009.
                    FilledButton(
                      onPressed: enviando ? null : _submit,
                      child: enviando
                          ? const SizedBox.square(
                              dimension: Tokens.fontSizeTitle,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.authLoginSubmit),
                    ),

                    if (state case AsyncError(:final error)) ...[
                      SizedBox(height: spacing.lg),
                      StatusChip(
                        tone: _toneFor(error),
                        label: _messageFor(error, l10n),
                        expand: true,
                      ),
                    ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sin conexión no es culpa del usuario: se muestra como aviso, no como error.
  StatusTone _toneFor(Object error) {
    final failure = error is ApiFailure ? error : null;
    return failure != null && failure.isNoConnection
        ? StatusTone.warning
        : StatusTone.danger;
  }

  String _messageFor(Object error, AppLocalizations l10n) {
    final kind = error is ApiFailure ? error.kind : ApiFailureKind.unknown;
    return switch (kind) {
      ApiFailureKind.invalidCredentials => l10n.authLoginErrorCredentials,
      ApiFailureKind.noConnection => l10n.authLoginErrorNoConnection,
      ApiFailureKind.server => l10n.authLoginErrorServer,
      ApiFailureKind.unknown => l10n.authLoginErrorUnknown,
    };
  }
}
