import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/theme_extensions.dart';
import '../theme/tokens.dart';

/// El símbolo de Snapline: el cordel de tiza antes de tensarse y la línea que
/// queda marcada al soltarlo. Réplica de `brand/logo-mark.svg`.
///
/// Se dibuja en vez de cargar un SVG para no arrastrar `flutter_svg` por dos
/// círculos y dos trazos.
class SnaplineMark extends StatelessWidget {
  const SnaplineMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(color ?? context.colors.onSurfaceVariant),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  // El SVG está dibujado sobre un lienzo de 32; acá se escala a lo que pidan.
  static const _viewBox = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _viewBox;
    Offset p(double x, double y) => Offset(x * k, y * k);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // El cordel suelto, secundario a propósito: es el gesto, no la marca.
    canvas.drawPath(
      Path()
        ..moveTo(7 * k, 9 * k)
        ..quadraticBezierTo(16 * k, 27 * k, 25 * k, 23 * k),
      stroke
        ..strokeWidth = 2 * k
        ..color = color.withValues(alpha: 0.3),
    );

    canvas.drawLine(
      p(7, 9),
      p(25, 23),
      stroke
        ..strokeWidth = 3 * k
        ..color = color,
    );

    final fill = Paint()..color = color;
    canvas.drawCircle(p(7, 9), 3.25 * k, fill);
    canvas.drawCircle(p(25, 23), 3.25 * k, fill);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// Símbolo y nombre juntos.
///
/// El wordmark es la **única** cosa de la app en Bricolage Grotesque; todo el
/// resto del texto es Inter. Ver ADR-0009.
class SnaplineLogo extends StatelessWidget {
  const SnaplineLogo({
    super.key,
    this.color,
    this.markColor,
    this.markSize = 24,
  });

  /// Por defecto va en el color atenuado: en una pantalla de trabajo la marca
  /// acompaña. Pasar `context.colors.onSurface` donde deba tener presencia.
  final Color? color;

  /// Solo el símbolo. Sirve para destacarlo en el color de marca dejando el
  /// nombre en el color de texto.
  final Color? markColor;

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.colors.onSurfaceVariant;
    final nombre = Text(
      AppLocalizations.of(context).appTitle,
      style: TextStyle(
        fontFamily: Tokens.fontFamilyBrand,
        fontWeight: Tokens.weightBrand,
        // El nombre escala con el símbolo: un solo número mueve el lockup.
        fontSize: markSize * 0.92,
        letterSpacing: -0.5,
        height: 1.1,
        color: resolved,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SnaplineMark(size: markSize, color: markColor ?? resolved),
        SizedBox(width: context.spacing.sm * (markSize / 24)),
        // Sin esto, un tamaño grande desborda en pantallas angostas.
        Flexible(child: FittedBox(child: nombre)),
      ],
    );
  }
}

/// La marca cuando es protagonista: símbolo arriba, nombre debajo.
///
/// Un lockup horizontal grande se queda sin ancho antes de tener presencia; en
/// vertical el símbolo puede crecer sin apretar el nombre.
class SnaplineLogoStacked extends StatelessWidget {
  const SnaplineLogoStacked({super.key, this.color, this.markSize = 104});

  final Color? color;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.colors.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SnaplineMark(size: markSize, color: resolved),
        SizedBox(height: context.spacing.lg),
        FittedBox(
          child: Text(
            AppLocalizations.of(context).appTitle,
            style: TextStyle(
              fontFamily: Tokens.fontFamilyBrand,
              fontWeight: Tokens.weightBrand,
              // El símbolo no llena su cuadro —la línea deja aire arriba y
              // abajo—, así que el nombre va a menos ratio del que parecería.
              fontSize: markSize * 0.44,
              letterSpacing: -1,
              height: 1,
              color: resolved,
            ),
          ),
        ),
      ],
    );
  }
}
