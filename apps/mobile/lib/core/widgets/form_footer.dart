import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// El pie de un formulario: su acción primaria, anclada abajo.
///
/// **Respeta el área segura de abajo.** Sin eso, en cualquier teléfono con barra
/// gestual el botón queda debajo de la franja del sistema: se ve entero y el
/// toque en su mitad inferior se lo lleva el sistema, así que parece que la app
/// ignora el tap.
///
/// El borde arriba no es decorativo: separa la acción del contenido que
/// scrollea, o el botón se lee como parte del último campo.
class FormFooter extends StatelessWidget {
  const FormFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: SafeArea(
        // Solo abajo: los lados y el notch los maneja el `Scaffold`, y volver a
        // aplicarlos acá agregaría el margen dos veces.
        top: false,
        left: false,
        right: false,
        child: Padding(padding: EdgeInsets.all(spacing.lg), child: child),
      ),
    );
  }
}
