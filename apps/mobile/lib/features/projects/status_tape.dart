import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';

/// El estado de la obra como una cinta de peligro: franjas diagonales y el
/// texto encima.
///
/// Es el lenguaje del oficio —la cinta que se ve en cualquier obra— y no
/// depende del color para leerse: las franjas mismas son la señal, así que
/// funciona igual al sol, en un sótano y para alguien que no distingue verde de
/// ámbar.
class StatusTape extends StatelessWidget {
  const StatusTape({super.key, required this.tone, required this.label});

  final StatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final (fondo, frente) = _colores(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(spacing.radiusSm),
      child: CustomPaint(
        painter: _FranjasPainter(fondo: fondo, franja: frente),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          alignment: Alignment.center,
          child: Container(
            // El texto sobre las franjas no se leería: va sobre su propio
            // fondo, como la etiqueta de una cinta de verdad.
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xs,
            ),
            color: fondo,
            child: Text(
              label.toUpperCase(),
              style: context.texts.bodySmall?.copyWith(
                color: frente,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _colores(BuildContext context) {
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

/// Las diagonales. Van a 45 grados y con el mismo ancho que el espacio entre
/// ellas, que es como se ve una cinta de obra.
class _FranjasPainter extends CustomPainter {
  const _FranjasPainter({required this.fondo, required this.franja});

  final Color fondo;
  final Color franja;

  static const _ancho = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fondo);

    final pincel = Paint()
      ..color = franja
      ..strokeWidth = _ancho
      ..style = PaintingStyle.stroke;

    // Se arranca antes del borde izquierdo para que la primera diagonal entre
    // completa en vez de aparecer cortada en una esquina.
    for (var x = -size.height; x < size.width + size.height; x += _ancho * 2) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), pincel);
    }
  }

  @override
  bool shouldRepaint(_FranjasPainter oldDelegate) =>
      oldDelegate.fondo != fondo || oldDelegate.franja != franja;
}
