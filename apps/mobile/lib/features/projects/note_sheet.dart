import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/app_localizations.dart';
import 'photos_tab.dart';

/// Escribir una nota de la bitácora.
///
/// Dos cosas de acá no son cosméticas: **el aviso de Etapas**, sin el cual
/// alguien cree que le mandó algo al cliente y del otro lado no hay nada; y el
/// conteo de **cuántas fotos suben de nivel**, que es lo único que esta hoja
/// toca fuera de la nota que se está escribiendo.
Future<void> mostrarHojaDeNota(
  BuildContext context,
  WidgetRef ref,
  String projectId, {
  VoidCallback? irADetalle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _HojaDeNota(projectId: projectId, irADetalle: irADetalle),
    ),
  );
}

class _HojaDeNota extends ConsumerStatefulWidget {
  const _HojaDeNota({required this.projectId, this.irADetalle});

  final String projectId;
  final VoidCallback? irADetalle;

  @override
  ConsumerState<_HojaDeNota> createState() => _HojaDeNotaState();
}

class _HojaDeNotaState extends ConsumerState<_HojaDeNota> {
  final _texto = TextEditingController();
  final _seleccionadas = <String>{};

  /// Interna es el default: la bitácora es de la obra, y que el cliente vea algo
  /// es una decisión y no un descuido.
  bool _paraElCliente = false;
  bool _intentoGuardar = false;
  bool _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    final proyecto = ref.watch(projectDetailProvider(widget.projectId)).value;
    final enEtapas = proyecto?.clientVisibilityMode == 'STAGES';

    final fotos = ref.watch(fotosDeLaObraProvider(widget.projectId)).value ??
        const [];
    // Cuántas de las elegidas van a cambiar de nivel al guardar. Se cuenta con
    // lo que hay en pantalla, que es lo que la persona está mirando.
    final suben = fotos
        .where((f) => _seleccionadas.contains(f.id) && f.visibility == 'INTERNAL')
        .length;

    final vacio = _texto.text.trim().isEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            spacing.lg, spacing.sm, spacing.lg, spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.noteSheetTitle, style: context.texts.titleLarge),
            SizedBox(height: spacing.lg),

            TextField(
              controller: _texto,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.noteSheetBodyHint,
                border: const OutlineInputBorder(),
                errorText: _intentoGuardar && vacio
                    ? l10n.noteSheetBodyRequired
                    : null,
              ),
            ),

            if (fotos.isNotEmpty) ...[
              SizedBox(height: spacing.lg),
              Text(l10n.noteSheetPhotos,
                  style: context.texts.labelLarge
                      ?.copyWith(color: colors.onSurfaceVariant)),
              SizedBox(height: spacing.sm),
              _Selector(
                fotos: fotos,
                seleccionadas: _seleccionadas,
                onToggle: (id) => setState(() {
                  _seleccionadas.contains(id)
                      ? _seleccionadas.remove(id)
                      : _seleccionadas.add(id);
                }),
              ),
              if (fotos.any((f) => !f.subida))
                Padding(
                  padding: EdgeInsets.only(top: spacing.xs),
                  child: Text(
                    l10n.noteSheetPhotoNotSynced,
                    style: context.texts.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
            ],

            SizedBox(height: spacing.lg),
            Text(l10n.noteSheetWhoSees,
                style: context.texts.labelLarge
                    ?.copyWith(color: colors.onSurfaceVariant)),
            SizedBox(height: spacing.sm),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.noteSheetInternal)),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l10n.noteSheetForClient),
                ),
              ],
              selected: {_paraElCliente},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _paraElCliente = s.first),
            ),

            // El aviso llega con su salida: sin poder cambiar el modo, marcar
            // una nota para el cliente no haría nada, nunca.
            if (_paraElCliente && enEtapas) ...[
              SizedBox(height: spacing.md),
              _AvisoDeEtapas(irADetalle: widget.irADetalle),
            ],

            if (_paraElCliente && suben > 0) ...[
              SizedBox(height: spacing.md),
              Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 18, color: colors.onSurfaceVariant),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      l10n.noteSheetPhotosWillBeVisible(suben),
                      style: context.texts.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: spacing.lg),
            // Un solo sólido por pantalla: guardar es la acción, descartar es
            // la salida.
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _guardando ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.noteSheetDiscard),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(l10n.noteSheetSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);
    if (_texto.text.trim().isEmpty) return;

    final sesion = ref.read(sessionControllerProvider).value;
    if (sesion == null) return;

    setState(() => _guardando = true);
    await ref.read(progressRepositoryProvider).escribirNota(
          projectId: widget.projectId,
          body: _texto.text.trim(),
          visibility: _paraElCliente ? 'CLIENT' : 'INTERNAL',
          authorMembershipId: sesion.membership.id,
          companyId: sesion.membership.companyId,
          assetIds: _seleccionadas.toList(growable: false),
        );

    if (mounted) Navigator.of(context).pop();
  }
}

/// El aviso de que la obra está en modo etapas.
///
/// **Solo avisa y lleva; no cambia el modo.** El interruptor vive en la tab
/// Detalle porque `client_visibility_mode` es una propiedad de la obra y no de
/// la nota que se está escribiendo. Duplicarlo acá lo convertiría en un efecto
/// de escribir una nota.
class _AvisoDeEtapas extends StatelessWidget {
  const _AvisoDeEtapas({this.irADetalle});

  final VoidCallback? irADetalle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(spacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: colors.onTertiaryContainer),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.noteSheetStagesWarning,
                  style: context.texts.bodySmall
                      ?.copyWith(color: colors.onTertiaryContainer),
                ),
                // Sin la tab Detalle a la vista no hay a dónde mandar a nadie:
                // el aviso informa y ahí termina.
                if (irADetalle != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: colors.onTertiaryContainer,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      irADetalle!();
                    },
                    child: Text(l10n.noteSheetChangeMode),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las fotos de la obra, para elegir.
///
/// Una que todavía no subió se ve pero **no se puede adjuntar**: el servidor
/// recibiría una nota apuntando a un asset que para él no existe, y fallaría
/// entera por una clave foránea.
class _Selector extends StatelessWidget {
  const _Selector({
    required this.fotos,
    required this.seleccionadas,
    required this.onToggle,
  });

  final List<ObraFoto> fotos;
  final Set<String> seleccionadas;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fotos.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.sm),
        itemBuilder: (context, i) {
          final foto = fotos[i];
          final elegida = seleccionadas.contains(foto.id);

          return Opacity(
            opacity: foto.subida ? 1 : .38,
            child: GestureDetector(
              onTap: foto.subida ? () => onToggle(foto.id) : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(spacing.radiusSm),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: FotoDeObra(foto: foto, fit: BoxFit.cover),
                    ),
                  ),
                  if (elegida)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .35),
                          borderRadius:
                              BorderRadius.circular(spacing.radiusSm),
                          border: Border.all(color: colors.primary, width: 2),
                        ),
                        child: Icon(Icons.check_circle,
                            color: colors.onPrimary, size: 22),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
