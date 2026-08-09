import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';
import 'account_button.dart';

/// La forma de cualquier pantalla de eje: título a la izquierda y la cuenta a
/// la derecha. Existe para que las pantallas que vienen no vuelvan a decidir
/// cómo se ve su barra.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        actions: [...actions, const AccountButton()],
      ),
      body: body,
    );
  }
}
