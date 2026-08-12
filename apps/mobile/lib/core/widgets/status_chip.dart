import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

enum StatusTone { warning, success, danger, info }

extension StatusToneDisplay on StatusTone {
  IconData get icon => switch (this) {
    StatusTone.warning => Icons.warning_amber_rounded,
    StatusTone.success => Icons.check_circle_outline,
    StatusTone.danger => Icons.error_outline,
    StatusTone.info => Icons.info_outline,
  };

  /// El color del tono sobre una superficie normal — para el icono de una
  /// [StatusLine], donde no hay relleno que lo sostenga.
  Color color(BuildContext context) => switch (this) {
    StatusTone.warning => context.statusColors.warning,
    StatusTone.success => context.statusColors.success,
    StatusTone.danger => context.colors.error,
    StatusTone.info => context.colors.onSurfaceVariant,
  };
}

/// El estado **en una fila de lista**: icono con el color del tono y el texto
/// atenuado, sin relleno.
///
/// Un [StatusChip] por fila convierte cada renglón en un globo de color que
/// pesa más que el nombre y más que la acción — y el estado es lectura, no
/// acción. El chip queda para lo que aparece de a uno: una bandera, un aviso,
/// el estado de una jornada abierta.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.tone, required this.label});

  final StatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(tone.icon, size: context.spacing.lg, color: tone.color(context)),
        SizedBox(width: context.spacing.xs),
        Flexible(
          child: Text(
            label,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// La forma en que la app muestra un estado: fondo tenue, texto oscuro e icono.
///
/// Existe para que la regla del ADR-0009 se cumpla por construcción. El naranja
/// saturado es solo de la acción primaria, así que un estado nunca se pinta con
/// relleno sólido, y **nunca** se comunica solo con color: el icono es parte del
/// widget, no una decisión de quien lo usa.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.tone,
    required this.label,
    this.icon,
    this.expand = false,
    this.subtle = false,
    this.action,
  });

  final StatusTone tone;
  final String label;

  /// Solo para casos donde el icono por defecto del tono no describe bien lo
  /// que pasó. Nunca para quitarlo.
  final IconData? icon;

  /// Ancho completo, para errores de formulario. Compacto para banderas.
  final bool expand;

  /// Al final del chip, para un aviso que necesita explicarse: un `HelpButton`.
  ///
  /// Solo tiene sentido con [expand]: en un chip compacto no queda lugar, y un
  /// aviso que da una noticia sin explicar de qué habla no sirve de nada.
  final Widget? action;

  /// Sin relleno: solo el contorno, el icono y el texto.
  ///
  /// Para donde el estado se repite muchas veces —una lista de obras— y el
  /// relleno se vuelve una mancha de color que cansa. La información es la
  /// misma; lo que baja es cuánta tinta ocupa.
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final (background, foreground) = _colors(context);

    return Container(
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: subtle ? spacing.sm : spacing.md,
        vertical: subtle ? spacing.xs : spacing.sm,
      ),
      decoration: BoxDecoration(
        color: subtle ? null : background,
        border: subtle ? Border.all(color: foreground.withValues(alpha: 0.4)) : null,
        borderRadius: BorderRadius.circular(
          expand ? spacing.radiusMd : spacing.radiusFull,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            icon ?? _defaultIcon,
            size: subtle ? spacing.md : spacing.lg,
            color: foreground,
          ),
          SizedBox(width: subtle ? spacing.xs : spacing.sm),
          Flexible(
            child: Text(
              label,
              style: (subtle ? context.texts.bodySmall : context.texts.bodyMedium)
                  ?.copyWith(
                    color: foreground,
                    fontWeight: subtle ? FontWeight.w500 : null,
                  ),
            ),
          ),
          if (action != null) ...[SizedBox(width: spacing.xs), action!],
        ],
      ),
    );
  }

  IconData get _defaultIcon => tone.icon;

  (Color, Color) _colors(BuildContext context) {
    final status = context.statusColors;
    final colors = context.colors;
    return switch (tone) {
      StatusTone.warning => (
        status.warningContainer,
        status.onWarningContainer,
      ),
      StatusTone.success => (
        status.successContainer,
        status.onSuccessContainer,
      ),
      StatusTone.danger => (colors.errorContainer, colors.onErrorContainer),
      StatusTone.info => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
  }
}
