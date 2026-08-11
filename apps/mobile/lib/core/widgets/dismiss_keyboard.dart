import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Tocar fuera de un campo cierra el teclado.
///
/// Envuelve la app entera desde `MaterialApp.builder`, así que vale en toda
/// pantalla, hoja y diálogo sin que ninguno tenga que acordarse. Resolverlo por
/// pantalla es olvidarse en una, y la que se olvida es la que el usuario encuentra.
///
/// El teclado tapa media pantalla en un teléfono: sin esto, quien terminó de
/// escribir la dirección de una propiedad no puede ver el resto del formulario ni
/// el botón de guardar sin buscar una tecla de bajar que en iOS no existe.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `Listener` y no `GestureDetector`: el gesto lo gana el hijo —una card, un
    // botón, el scroll— y un `onTap` de ancestro nunca llega a dispararse. Los
    // eventos de puntero, en cambio, pasan por todo el camino.
    return Listener(
      onPointerDown: (evento) => _quizasCerrar(evento),
      child: child,
    );
  }

  /// Cierra el teclado salvo que el toque haya caído sobre un campo de texto.
  ///
  /// La excepción es lo que evita el parpadeo: al pasar de un campo al siguiente,
  /// cerrar y volver a abrir el teclado lo hace saltar en la cara del usuario.
  static void _quizasCerrar(PointerDownEvent evento) {
    final foco = FocusManager.instance.primaryFocus;
    if (!(foco?.hasFocus ?? false)) return;

    if (_sobreUnCampo(evento)) return;
    foco!.unfocus();
  }

  static bool _sobreUnCampo(PointerDownEvent evento) {
    final resultado = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      resultado,
      evento.position,
      evento.viewId,
    );
    // `RenderEditable` es el render de cualquier campo de texto, incluidos los que
    // vienen dentro de un paquete.
    return resultado.path.any((entrada) => entrada.target is RenderEditable);
  }
}
