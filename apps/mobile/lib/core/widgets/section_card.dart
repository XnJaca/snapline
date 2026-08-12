import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Una sección con su nombre adentro: banda con fondo arriba, contenido abajo,
/// todo dentro del mismo marco.
///
/// **El label nunca va suelto sobre el fondo.** Un texto flotando sobre el
/// lienzo no se lee como el título de lo que sigue, se lee como algo que se
/// quedó ahí — y la app se usa sin entrenamiento, así que cada bloque tiene
/// que decir qué es sin que nadie lo explique.
///
/// [padded] en `false` cuando el hijo trae su propio padding: filas de una
/// lista que llegan hasta el borde.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.label,
    required this.child,
    this.padded = true,
  });

  final String label;
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(spacing.radiusMd),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: context.colors.surfaceContainerHighest,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            child: Text(
              label,
              style: context.texts.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: padded ? EdgeInsets.all(spacing.md) : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}
