import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// La acción primaria de una pantalla **de campo**: 64 de alto y ancho completo.
///
/// Se pide explícitamente y no sale del tema porque no toda acción sólida la
/// necesita. Los 64 son para el dedo con guante de trabajo sobre un techo
/// —marcar asistencia, tomar la foto—, no para el "Guardar" de un formulario
/// administrativo, que a esa altura se come el espacio de los campos.
///
/// Ver ADR-0009 y `Tokens.touchTargetField`.
class FieldActionButton extends StatelessWidget {
  const FieldActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(Tokens.touchTargetField),
      textStyle: const TextStyle(
        fontFamily: Tokens.fontFamily,
        fontSize: Tokens.fontSizeTitle,
        fontWeight: Tokens.weightMedium,
      ),
    );

    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
