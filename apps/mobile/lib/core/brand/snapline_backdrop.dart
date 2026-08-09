import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// El gesto de la marca a escala de pantalla: el cordel tensado y la línea que
/// deja marcada, cruzando el fondo.
///
/// Va a opacidad muy baja a propósito. Es textura de marca, no decoración: si
/// compite con el formulario o baja el contraste del texto, está mal puesta.
class SnaplineBackdrop extends StatelessWidget {
  const SnaplineBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _BackdropPainter(context.colors.primary)),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Arriba del bloque de marca a propósito: el símbolo ya es una diagonal, y
    // dos diagonales del mismo gesto cruzadas se leen como una sola cosa rota.
    final inicio = Offset(-size.width * 0.1, size.height * 0.03);
    final fin = Offset(size.width * 1.1, size.height * 0.17);

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // El cordel colgando, antes del tirón.
    canvas.drawPath(
      Path()
        ..moveTo(inicio.dx, inicio.dy)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * 0.26,
          fin.dx,
          fin.dy,
        ),
      trazo
        ..strokeWidth = 10
        ..color = color.withValues(alpha: 0.05),
    );

    // La línea marcada.
    canvas.drawLine(
      inicio,
      fin,
      trazo
        ..strokeWidth = 14
        ..color = color.withValues(alpha: 0.09),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.color != color;
}
