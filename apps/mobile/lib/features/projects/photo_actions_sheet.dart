import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/media_repository.dart';
import '../../l10n/app_localizations.dart';
import 'photo_tag_sheet.dart';

/// Qué se puede hacer con una foto ya tomada.
///
/// Etiquetar entra con `media.capture` y cambiar el nivel con
/// `media.visibility`: el trabajador que sacó la foto puede corregir qué
/// muestra, pero publicar es de oficina. Sin ninguno de los dos la hoja no se
/// abre — la miniatura no responde al toque.
Future<void> mostrarAccionesDeFoto(
  BuildContext context,
  WidgetRef ref,
  ObraFoto foto, {
  required bool puedeEtiquetar,
  required bool puedeCambiarNivel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _Acciones(
      foto: foto,
      puedeEtiquetar: puedeEtiquetar,
      puedeCambiarNivel: puedeCambiarNivel,
    ),
  );
}

class _Acciones extends ConsumerStatefulWidget {
  const _Acciones({
    required this.foto,
    required this.puedeEtiquetar,
    required this.puedeCambiarNivel,
  });

  final ObraFoto foto;
  final bool puedeEtiquetar;
  final bool puedeCambiarNivel;

  @override
  ConsumerState<_Acciones> createState() => _AccionesState();
}

class _AccionesState extends ConsumerState<_Acciones> {
  var _enCurso = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final foto = widget.foto;
    final siguiente = _siguienteEscalon(foto.visibility);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusLine(
              tone: switch (foto.visibility) {
                'PUBLIC' => StatusTone.success,
                'CLIENT' => StatusTone.info,
                _ => StatusTone.info,
              },
              label: _nivelEnTexto(foto.visibility, l10n),
            ),
            if (foto.tags.isNotEmpty) ...[
              SizedBox(height: spacing.xs),
              Text(
                etiquetasEnTexto(foto.tags, l10n),
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: spacing.md),
              StatusChip(tone: StatusTone.danger, label: _error!, expand: true),
            ],
            SizedBox(height: spacing.lg),

            if (widget.puedeEtiquetar)
              _Accion(
                icon: Icons.label_outline,
                label: foto.tags.isEmpty
                    ? l10n.photosAddTags
                    : l10n.photosEditTags,
                onTap: _enCurso ? null : _editarEtiquetas,
              ),

            if (widget.puedeCambiarNivel) ...[
              if (siguiente != null)
                _Accion(
                  icon: siguiente == 'PUBLIC'
                      ? Icons.public
                      : Icons.visibility_outlined,
                  label: siguiente == 'PUBLIC'
                      ? l10n.photosRaiseToPublic
                      : l10n.photosRaiseToClient,
                  destacada: true,
                  onTap: _enCurso ? null : () => _mover(siguiente),
                ),
              if (foto.visibility != 'INTERNAL')
                _Accion(
                  icon: Icons.visibility_off_outlined,
                  label: l10n.photosLowerVisibility,
                  onTap: _enCurso ? null : () => _mover('INTERNAL'),
                ),
              SizedBox(height: spacing.sm),
              Text(
                l10n.photosLadderNote,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editarEtiquetas() async {
    final elegidas = await mostrarHojaDeEtiquetas(
      context,
      iniciales: widget.foto.tags,
    );
    if (elegidas == null || !mounted) return;

    // Va por la bandeja: corregir qué muestra una foto no exige señal.
    await ref.read(mediaRepositoryProvider).setTags(widget.foto.id, elegidas);
    if (mounted) Navigator.of(context).pop();
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

/// Una acción como fila alta: el mismo blanco que las etiquetas, por la misma
/// razón — esto se toca con guantes.
class _Accion extends StatelessWidget {
  const _Accion({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destacada = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// La que sigue en la escalera. Una sola por hoja, o ninguna es la acción.
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Material(
        color: destacada ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(spacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(spacing.radiusMd),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              children: [
                Icon(icon,
                    color: destacada
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: context.texts.titleMedium?.copyWith(
                      color: destacada
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
