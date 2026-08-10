import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/form_footer.dart';
import '../../l10n/app_localizations.dart';

/// La forma de una hoja de formulario: título, campos scrolleables y la acción
/// primaria al pie.
///
/// Existe para que las hojas de cliente y de propiedad no decidan cada una su
/// alto, su padding y dónde va el botón — y para que el teclado no tape el
/// último campo, que es el error que se descubre recién en el teléfono.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.formKey,
    required this.onSave,
    required this.saveLabel,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;

  /// `null` deshabilita el botón, para no guardar dos veces con un doble toque.
  final VoidCallback? onSave;

  final String saveLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    // El alto lo pone el contenido, con techo: una hoja que arranca a pantalla
    // completa no se lee como algo de lo que se puede salir.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.lg,
                  spacing.sm,
                  spacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: context.texts.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.actionCancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 0, color: colors.outline),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
              // La única acción naranja sólida de la hoja. `FormFooter` le da el
              // área segura de abajo: en una hoja el botón queda pegado al borde
              // de la pantalla, justo donde vive la barra gestual.
              FormFooter(
                child: FilledButton(onPressed: onSave, child: Text(saveLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
