import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/form_footer.dart';
import '../../l10n/app_localizations.dart';

/// Por qué se rechaza una jornada.
///
/// **Rechazar pide motivo y aprobar no.** No es simetría rota por descuido: el
/// rechazo es el que le saca el día a alguien, y sin el porqué esa persona se
/// entera de que no le contó el día pero no de la razón.
///
/// Devuelve `null` si se salió sin rechazar; el motivo escrito si se confirmó.
Future<String?> pedirMotivoDeRechazo(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _HojaDeRechazo(),
  );
}

class _HojaDeRechazo extends StatefulWidget {
  const _HojaDeRechazo();

  @override
  State<_HojaDeRechazo> createState() => _HojaDeRechazoState();
}

class _HojaDeRechazoState extends State<_HojaDeRechazo> {
  final _motivo = TextEditingController();

  @override
  void initState() {
    super.initState();
    // El botón se habilita al escribir: rechazar sin motivo deja el rastro sin
    // la única parte que le sirve a quien lo lea después.
    _motivo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final escrito = _motivo.text.trim();

    return Padding(
      // Sube con el teclado: si no, el campo queda tapado justo cuando se
      // escribe en él.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              0,
              spacing.lg,
              spacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hoursRejectTitle,
                  style: context.texts.titleMedium,
                ),
                SizedBox(height: spacing.xs),
                Text(
                  l10n.hoursRejectBody,
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                SizedBox(height: spacing.md),
                TextField(
                  controller: _motivo,
                  autofocus: true,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.hoursRejectReasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          FormFooter(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.hoursRejectCancel),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: escrito.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(escrito),
                    child: Text(l10n.hoursRejectConfirm),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
