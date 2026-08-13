import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
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

String etiquetasEnTexto(List<MediaTag> tags, AppLocalizations l10n) =>
    tags.map((t) => etiquetaEnTexto(t, l10n)).join(' · ');

/// Qué muestra la foto, elegido en el mismo gesto que tomarla.
///
/// Se puede omitir: una foto sin etiqueta entra igual. Pedirla como obligatoria
/// convierte cada disparo en un formulario, y esta app se usa con guantes.
Future<List<MediaTag>?> mostrarHojaDeEtiquetas(
  BuildContext context, {
  List<MediaTag> iniciales = const [],
}) {
  return showModalBottomSheet<List<MediaTag>>(
    context: context,
    isScrollControlled: true,
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.photosTagQuestion, style: context.texts.titleMedium),
            SizedBox(height: spacing.md),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final tag in MediaTag.values)
                  FilterChip(
                    label: Text(etiquetaEnTexto(tag, l10n)),
                    selected: _elegidas.contains(tag),
                    onSelected: (elegida) => setState(() {
                      elegida ? _elegidas.add(tag) : _elegidas.remove(tag);
                    }),
                  ),
              ],
            ),
            SizedBox(height: spacing.lg),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const <MediaTag>[]),
                  child: Text(l10n.photosTagSkip),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_elegidas.toList()),
                  child: Text(l10n.photosTagSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
