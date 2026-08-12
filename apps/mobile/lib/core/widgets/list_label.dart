import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// La etiqueta chica de una lista: dice qué es lo que viene abajo.
///
/// Existe para que ningún dato quede suelto sobre el fondo — la sección se
/// nombra con esto y su contenido va en [InfoCard]s o tarjetas. Es texto de
/// apoyo, no contenido: atenuado y chico para no competir con lo que
/// presenta. Para el encabezado grande de una pantalla está [SectionHeader].
class ListLabel extends StatelessWidget {
  const ListLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Text(
        label,
        style: context.texts.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
