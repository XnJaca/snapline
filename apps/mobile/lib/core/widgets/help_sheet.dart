import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';
import '../../l10n/app_localizations.dart';

/// Explica algo que la interfaz nombra pero no puede explicar en una línea.
///
/// Es una hoja y no un diálogo: se cierra arrastrando, no obliga a acertarle a
/// un botón, y deja ver de dónde salió. Los textos llegan ya traducidos —quien
/// la abre pasa por `AppLocalizations`— y el cuerpo se parte en párrafos por
/// cada línea en blanco.
///
/// **La ayuda nunca es el único lugar donde está la información.** Si un
/// formulario necesita esto para entenderse, el label está mal escrito: acá va
/// el contexto de negocio que no cabe al lado de un campo.
Future<void> showHelpSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HelpSheet(title: title, body: body),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return ConstrainedBox(
      // Con techo: una hoja de ayuda a pantalla completa no se lee como algo de
      // lo que se puede salir sin leerla entera.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
            child: Row(
              children: [
                Icon(Icons.help_outline, color: colors.onSurfaceVariant),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Text(title, style: context.texts.titleLarge),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final parrafo in body.split('\n\n'))
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing.md),
                      child: Text(parrafo, style: context.texts.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          // Cerrar no es la acción primaria de nada: la hoja no pide una
          // decisión, así que va en texto y no en naranja sólido.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.helpClose),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón que abre la ayuda. Va pegado a lo que explica.
class HelpButton extends StatelessWidget {
  const HelpButton({
    super.key,
    required this.title,
    required this.body,
    this.label,
  });

  final String title;
  final String body;

  /// Con texto cuando la ayuda es parte del mensaje —"Saber más"— y solo icono
  /// cuando acompaña un título y el texto sería ruido.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    void abrir() => showHelpSheet(context, title: title, body: body);

    if (label == null) {
      return IconButton(
        icon: const Icon(Icons.help_outline),
        tooltip: l10n.helpMoreInfo,
        onPressed: abrir,
        visualDensity: VisualDensity.compact,
      );
    }
    return TextButton(onPressed: abrir, child: Text(label!));
  }
}
