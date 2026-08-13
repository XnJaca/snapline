import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/media_repository.dart';
import '../../l10n/app_localizations.dart';

/// Subir o bajar el nivel de una foto.
///
/// **Solo se ofrece el próximo escalón.** La escalera sube de a uno y el
/// servidor lo rechaza con `VISIBILITY_SKIPS_STEP` si se saltea, así que la
/// pantalla no ofrece un camino que va a fallar. Bajar no se restringe: sacar
/// algo de la vista es siempre urgente.
///
/// **Requiere red y no se encola.** Publicar es una decisión deliberada, no
/// algo que deba ejecutarse solo horas después, cuando quien lo decidió ya no
/// está mirando.
Future<void> mostrarHojaDeVisibilidad(
  BuildContext context,
  WidgetRef ref,
  ObraFoto foto,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => _HojaDeVisibilidad(foto: foto),
  );
}

class _HojaDeVisibilidad extends ConsumerStatefulWidget {
  const _HojaDeVisibilidad({required this.foto});

  final ObraFoto foto;

  @override
  ConsumerState<_HojaDeVisibilidad> createState() => _HojaState();
}

class _HojaState extends ConsumerState<_HojaDeVisibilidad> {
  var _enCurso = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final actual = widget.foto.visibility;
    final siguiente = _siguienteEscalon(actual);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusLine(
              tone: switch (actual) {
                'PUBLIC' => StatusTone.success,
                'CLIENT' => StatusTone.info,
                _ => StatusTone.info,
              },
              label: _nivelEnTexto(actual, l10n),
            ),
            SizedBox(height: spacing.md),
            Text(l10n.photosLadderNote,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
            if (_error != null) ...[
              SizedBox(height: spacing.md),
              StatusChip(
                  tone: StatusTone.danger, label: _error!, expand: true),
            ],
            SizedBox(height: spacing.lg),
            if (siguiente != null)
              FilledButton.icon(
                onPressed: _enCurso ? null : () => _mover(siguiente),
                icon: Icon(siguiente == 'PUBLIC'
                    ? Icons.public
                    : Icons.visibility_outlined),
                label: Text(siguiente == 'PUBLIC'
                    ? l10n.photosRaiseToPublic
                    : l10n.photosRaiseToClient),
              ),
            if (actual != 'INTERNAL') ...[
              SizedBox(height: spacing.sm),
              TextButton.icon(
                onPressed: _enCurso ? null : () => _mover('INTERNAL'),
                icon: const Icon(Icons.visibility_off_outlined),
                label: Text(l10n.photosLowerVisibility),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _mover(String visibility) async {
    setState(() {
      _enCurso = true;
      _error = null;
    });
    try {
      await ref
          .read(mediaRepositoryProvider)
          .cambiarVisibilidad(widget.foto.id, visibility);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      // Sin red o rechazo del servidor: se dice y la hoja queda abierta, en vez
      // de cerrarse como si hubiera funcionado.
      setState(() {
        _enCurso = false;
        _error = AppLocalizations.of(context).photosNeedsNetwork;
      });
    }
  }
}

String? _siguienteEscalon(String actual) => switch (actual) {
      'INTERNAL' => 'CLIENT',
      'CLIENT' => 'PUBLIC',
      _ => null,
    };

String _nivelEnTexto(String visibility, AppLocalizations l10n) =>
    switch (visibility) {
      'PUBLIC' => l10n.photosVisibilityPublic,
      'CLIENT' => l10n.photosVisibilityClient,
      _ => l10n.photosVisibilityInternal,
    };
