import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// La card estándar de contenido: superficie con borde y esquinas del tema.
///
/// Todo dato que se muestre va adentro de una — un texto suelto sobre el
/// fondo parece un error de layout, no información. Las tarjetas tocables de
/// color (obras, cuadrillas) son otra cosa: esas llevan `primaryContainer` y
/// su propio `Material`.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(context.spacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(context.spacing.radiusMd),
        border: Border.all(color: context.colors.outline),
      ),
      child: child,
    );
  }
}
