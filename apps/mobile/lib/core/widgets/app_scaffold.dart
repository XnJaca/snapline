import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';
import 'account_button.dart';
import 'offline_banner.dart';

/// La forma de cualquier pantalla de eje: título a la izquierda y la cuenta a
/// la derecha. Existe para que las pantallas que vienen no vuelvan a decidir
/// cómo se ve su barra.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottom,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Va pegado bajo el título, dentro de la barra. Para tabs: colgadas del
  /// `AppBar` quedan ancladas, sueltas sobre el fondo flotan.
  final PreferredSizeWidget? bottom;

  /// La acción primaria de la pantalla, y la única naranja sólida.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        actions: [...actions, const AccountButton()],
        bottom: bottom,
      ),
      // La franja de sin conexión va arriba de todo el contenido: es el
      // contexto de lo que se está viendo abajo.
      body: Column(
        children: [const OfflineBanner(), Expanded(child: body)],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
