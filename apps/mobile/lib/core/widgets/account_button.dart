import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../l10n/app_localizations.dart';

/// La puerta a la cuenta. Vive en la barra de cada eje porque la navegación por
/// rol no tiene ninguna otra pantalla de perfil.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: l10n.accountTitle,
      onPressed: () => context.push(AccountScreen.route),
    );
  }
}
