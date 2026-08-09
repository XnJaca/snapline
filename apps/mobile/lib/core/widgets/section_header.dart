import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Encabezado de una sección dentro de una pantalla. Existe para que el
/// contenido no arranque pegado al borde sin decir qué es.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;

  /// A la derecha del título. Acá y no al pie de la lista: una acción al final
  /// de algo scrolleable solo la encuentra quien ya sabía que estaba.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleLarge),
              if (subtitle != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  subtitle!,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[SizedBox(width: spacing.md), action!],
      ],
    );
  }
}
