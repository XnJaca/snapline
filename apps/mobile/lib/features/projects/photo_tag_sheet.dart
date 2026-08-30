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
/// Etiquetar es opcional. En vez de un "Omitir" suelto al lado del guardar
/// —dos acciones que compiten y ninguna se lee— la acción primaria dice qué va
/// a pasar: sin nada elegido, guarda sin etiqueta.
Future<List<MediaTag>?> mostrarHojaDeEtiquetas(
  BuildContext context, {
  List<MediaTag> iniciales = const [],
}) {
  return showModalBottomSheet<List<MediaTag>>(
    context: context,
    isScrollControlled: true,
    // El contenido llega al pie: sin esto la acción queda bajo la barra
    // gestual y el sistema se lleva el toque.
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _HojaDeEtiquetas(iniciales: iniciales),
  );
}

class _HojaDeEtiquetas extends StatefulWidget {
  const _HojaDeEtiquetas({required this.iniciales});

  final List<MediaTag> iniciales;

  @override
  State<_HojaDeEtiquetas> createState() => _HojaDeEtiquetasState();
}

class _HojaDeEtiquetasState extends State<_HojaDeEtiquetas> {
  late final Set<MediaTag> _elegidas = {...widget.iniciales};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
          child: Text(l10n.photosTagTitle, style: context.texts.titleLarge),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            children: [
              for (final tag in MediaTag.values)
                _Opcion(
                  tag: tag,
                  elegida: _elegidas.contains(tag),
                  onTap: () => setState(() {
                    _elegidas.contains(tag)
                        ? _elegidas.remove(tag)
                        : _elegidas.add(tag);
                  }),
                ),
            ],
          ),
        ),
        FormFooter(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_elegidas.toList()),
            child: Text(
              _elegidas.isEmpty ? l10n.photosTagSaveWithout : l10n.photosTagSave,
            ),
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
                  elegida ? Icons.check_circle : Icons.circle_outlined,
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
