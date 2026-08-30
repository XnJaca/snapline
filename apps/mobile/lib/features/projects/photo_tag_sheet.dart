import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/form_footer.dart';
import '../../data/repositories/media_repository.dart';
import '../../l10n/app_localizations.dart';

/// El nombre de una etiqueta, traducido.
String etiquetaEnTexto(MediaTag tag, AppLocalizations l10n) => switch (tag) {
      MediaTag.before => l10n.photosTagBefore,
      MediaTag.after => l10n.photosTagAfter,
      MediaTag.during => l10n.photosTagDuring,
      MediaTag.detail => l10n.photosTagDetail,
      MediaTag.problem => l10n.photosTagProblem,
      MediaTag.receipt => l10n.photosTagReceipt,
    };

/// El icono de una etiqueta. El uno y el dos no son decorativos: dicen que
/// antes y después son un par y en qué orden va cada uno.
IconData etiquetaEnIcono(MediaTag tag) => switch (tag) {
      MediaTag.before => Icons.looks_one_outlined,
      MediaTag.after => Icons.looks_two_outlined,
      MediaTag.during => Icons.construction_outlined,
      MediaTag.detail => Icons.zoom_in,
      MediaTag.problem => Icons.warning_amber_rounded,
      MediaTag.receipt => Icons.receipt_long_outlined,
    };

String etiquetasEnTexto(List<MediaTag> tags, AppLocalizations l10n) =>
    tags.map((t) => etiquetaEnTexto(t, l10n)).join(' · ');

/// La etapa o categoría de la foto, elegida en el mismo gesto que tomarla.
///
/// **Filas altas y no chips**: esto se toca con guantes arriba de un techo, y
/// un chip de texto es un blanco de 32dp. Cada fila llega al mínimo táctil y
/// entera es tocable.
///
/// Devuelve `null` cuando no hay nada que guardar. Con [esFotoNueva] eso
/// significa descartarla, y en la corrección de una foto ya registrada,
/// dejarla como estaba.
Future<List<MediaTag>?> mostrarHojaDeEtiquetas(
  BuildContext context, {
  List<MediaTag> iniciales = const [],
  bool esFotoNueva = false,
}) {
  return showModalBottomSheet<List<MediaTag>>(
    context: context,
    isScrollControlled: true,
    // El contenido llega al pie: sin esto la acción queda bajo la barra
    // gestual y el sistema se lleva el toque.
    useSafeArea: true,
    // Una foto recién tomada sale por una de las dos acciones, nunca por un
    // deslizado: esquivar la hoja la dejaría sin etiqueta, que es justo lo que
    // no puede pasar.
    showDragHandle: !esFotoNueva,
    isDismissible: !esFotoNueva,
    enableDrag: !esFotoNueva,
    builder: (context) => PopScope(
      canPop: !esFotoNueva,
      child: _HojaDeEtiquetas(
        iniciales: iniciales,
        esFotoNueva: esFotoNueva,
      ),
    ),
  );
}

class _HojaDeEtiquetas extends StatefulWidget {
  const _HojaDeEtiquetas({required this.iniciales, required this.esFotoNueva});

  final List<MediaTag> iniciales;
  final bool esFotoNueva;

  @override
  State<_HojaDeEtiquetas> createState() => _HojaDeEtiquetasState();
}

class _HojaDeEtiquetasState extends State<_HojaDeEtiquetas> {
  /// Una sola. La galería agrupa por etiqueta, así que una foto con dos
  /// aparecería dos veces — el desorden que esto viene a ordenar.
  late MediaTag? _elegida = widget.iniciales.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Sin agarradera —el caso de la foto nueva— el título quedaba
          // pegado al borde de la hoja.
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            widget.esFotoNueva ? spacing.lg : 0,
            spacing.lg,
            spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.photosTagTitle, style: context.texts.titleLarge),
              SizedBox(height: spacing.xs),
              Text(
                l10n.photosTagHelp,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            children: [
              for (final tag in MediaTag.values)
                _Opcion(
                  tag: tag,
                  elegida: _elegida == tag,
                  onTap: () => setState(() => _elegida = tag),
                ),
            ],
          ),
        ),
        FormFooter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Sin etiqueta no hay dónde guardarla: el botón apagado dice
                  // que falta elegir, y el texto de arriba dice por qué.
                  onPressed: _elegida == null
                      ? null
                      : () => Navigator.of(context).pop([_elegida!]),
                  child: Text(l10n.photosTagSave),
                ),
              ),
              if (widget.esFotoNueva) ...[
                SizedBox(height: spacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.photosTagDiscard),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Una etiqueta como fila. El check a la derecha y el fondo tenue dicen lo
/// mismo dos veces a propósito: con sol directo el color solo no se ve.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.tag,
    required this.elegida,
    required this.onTap,
  });

  final MediaTag tag;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Material(
        color: elegida ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(spacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(spacing.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  etiquetaEnIcono(tag),
                  color: elegida ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Text(
                    etiquetaEnTexto(tag, l10n),
                    style: context.texts.titleMedium?.copyWith(
                      color: elegida ? colors.onPrimaryContainer : colors.onSurface,
                    ),
                  ),
                ),
                Icon(
                  elegida
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: elegida ? colors.onPrimaryContainer : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
