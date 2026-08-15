import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Confirmar algo que no tiene vuelta atrás.
///
/// **Hoja y no diálogo**, con las dos acciones como botones de ancho completo:
/// un `TextButton` abajo a la derecha de un `AlertDialog` no se lee como botón
/// —es texto suelto— y acá se toca con guantes. Las dos opciones tienen que
/// verse como opciones.
///
/// La destructiva va **arriba y en rojo**, la salida abajo con borde. Arriba
/// porque es la que se vino a hacer; en rojo porque el color es lo que dice que
/// no hay deshacer.
Future<bool> confirmarAccionDestructiva(
  BuildContext context, {
  required String titulo,
  required String cuerpo,
  required String confirmar,
  required String cancelar,
  IconData icono = Icons.delete_outline,
}) async {
  final confirmado = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _Confirmacion(
      titulo: titulo,
      cuerpo: cuerpo,
      confirmar: confirmar,
      cancelar: cancelar,
      icono: icono,
    ),
  );
  return confirmado ?? false;
}

class _Confirmacion extends StatelessWidget {
  const _Confirmacion({
    required this.titulo,
    required this.cuerpo,
    required this.confirmar,
    required this.cancelar,
    required this.icono,
  });

  final String titulo;
  final String cuerpo;
  final String confirmar;
  final String cancelar;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: colors.error),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(titulo, style: context.texts.titleLarge),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Text(
              cuerpo,
              style: context.texts.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            SizedBox(height: spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: Icon(icono),
                label: Text(confirmar),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelar),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
