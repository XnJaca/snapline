import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Un dato de una ficha: su etiqueta arriba y el valor abajo.
///
/// **Apilado y no en dos columnas.** La versión en columnas usaba un ancho fijo
/// para la etiqueta, y ahí "Nombre de la obra" se partía en tres líneas y
/// "Propiedad" se cortaba a la mitad — con el texto en español, que es más largo,
/// pasaba en casi todas. Apilado, la etiqueta y el valor tienen el ancho entero y
/// no hay nada que recortar.
///
/// **Lo que no está no se dibuja**: una ficha llena de "sin definir" no dice nada
/// y empuja hacia abajo lo que sí importa.
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.emptyPlaceholder,
  });

  final String label;
  final String? value;

  /// Qué mostrar cuando no hay valor. Sin esto la fila desaparece; con esto se
  /// muestra el texto —"sin definir"— para los casos donde la ausencia es parte
  /// de la información.
  final String? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    final vacio = value == null || value!.isEmpty;
    if (vacio && emptyPlaceholder == null) return const SizedBox.shrink();

    final spacing = context.spacing;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            vacio ? emptyPlaceholder! : value!,
            style: context.texts.bodyMedium?.copyWith(
              color: vacio ? colors.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}
