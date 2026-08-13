import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/photo_capture.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/field_action_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/media_repository.dart';
import '../../l10n/app_localizations.dart';
import 'photo_tag_sheet.dart';
import 'photo_actions_sheet.dart';

/// Las fotos de la obra.
///
/// Lo que se ve acá es lo que después se publica, así que no es un carrete: la
/// etiqueta se elige al tomarla y el nivel de visibilidad se ve de un vistazo.
///
/// Las del marcaje no entran — las filtra el repositorio. Son evidencia de que
/// alguien estaba parado ahí, no material de la obra.
class PhotosTab extends ConsumerWidget {
  const PhotosTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final fotos = ref.watch(fotosDeLaObraProvider(projectId));
    final permisos =
        ref.watch(sessionControllerProvider).value?.membership.permissions ??
            const <String>[];
    final puedeCambiarNivel = permisos.contains('media.visibility');
    // Corregir qué muestra una foto es parte de capturarla: el trabajador que
    // la sacó puede etiquetarla, aunque publicar no sea suyo.
    final puedeEtiquetar = permisos.contains('media.capture');

    return Column(
      children: [
        Expanded(
          child: switch (fotos) {
            AsyncData(:final value) when value.isEmpty => EmptyState(
                icon: Icons.photo_camera_outlined,
                message: '${l10n.photosEmptyTitle}\n\n${l10n.photosEmptyBody}',
              ),
            AsyncData(:final value) => _Grupos(
                grupos: agruparPorEtiqueta(value),
                onTap: puedeEtiquetar || puedeCambiarNivel
                    ? (foto) => mostrarAccionesDeFoto(
                          context,
                          ref,
                          foto,
                          puedeEtiquetar: puedeEtiquetar,
                          puedeCambiarNivel: puedeCambiarNivel,
                        )
                    : null,
              ),
            AsyncError() => EmptyState(
                icon: Icons.error_outline,
                message: l10n.photosEmptyTitle,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: FieldActionButton(
            icon: Icons.photo_camera_outlined,
            label: l10n.photosTakeAction,
            onPressed: () => _tomarFoto(context, ref),
          ),
        ),
      ],
    );
  }

  /// Toma, etiqueta y registra, en ese orden y sin salir de la pantalla.
  ///
  /// Nada de esto espera a la red: la fila local nace acá y la galería la
  /// muestra antes de que el servidor sepa que existe.
  Future<void> _tomarFoto(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final resultado =
        await ref.read(photoCaptureProvider).capture(PhotoQuality.portfolio);

    if (!context.mounted) return;
    if (!resultado.ok) {
      await _explicarFalla(context, l10n, resultado.failure!);
      return;
    }

    final etiquetas = await mostrarHojaDeEtiquetas(context);
    if (!context.mounted) return;

    final sesion = ref.read(sessionControllerProvider).value;
    await ref.read(mediaRepositoryProvider).registerPhoto(
          projectId: projectId,
          filePath: resultado.path!,
          companyId: sesion?.membership.companyId,
          tags: etiquetas ?? const [],
        );
  }

  /// Cancelar no dice nada: la persona ya sabe que canceló. Los otros dos sí,
  /// y el del permiso ofrece dónde arreglarlo — acá tomar la foto es la acción
  /// entera de la pantalla, no hay camino alternativo.
  Future<void> _explicarFalla(
    BuildContext context,
    AppLocalizations l10n,
    PhotoFailure falla,
  ) async {
    if (falla == PhotoFailure.cancelled) return;

    if (falla == PhotoFailure.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.photosCameraFailed)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.photosCameraDeniedTitle),
        content: Text(l10n.photosCameraDeniedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.photosOpenSettings),
          ),
        ],
      ),
    );
  }
}

/// Un grupo de la galería: una etiqueta y sus fotos.
class GrupoDeFotos {
  const GrupoDeFotos({required this.tag, required this.fotos});

  /// `null` es el grupo de las que no tienen etiqueta, que va último.
  final MediaTag? tag;
  final List<ObraFoto> fotos;
}

/// Agrupa por etiqueta, en el orden del dominio: antes, después, en proceso…
///
/// El orden importa para lo que se hace con esto: armar el par antes/después
/// es la pieza de marketing del producto, y con todo mezclado por fecha hay que
/// ir a buscar cuál era cuál. Una foto con dos etiquetas aparece en las dos —
/// es una foto, no una copia.
List<GrupoDeFotos> agruparPorEtiqueta(List<ObraFoto> fotos) {
  final grupos = <GrupoDeFotos>[];

  for (final tag in MediaTag.values) {
    final delGrupo = fotos.where((f) => f.tags.contains(tag)).toList();
    if (delGrupo.isNotEmpty) {
      grupos.add(GrupoDeFotos(tag: tag, fotos: delGrupo));
    }
  }

  final sinEtiqueta = fotos.where((f) => f.tags.isEmpty).toList();
  if (sinEtiqueta.isNotEmpty) {
    grupos.add(GrupoDeFotos(tag: null, fotos: sinEtiqueta));
  }

  return grupos;
}

class _Grupos extends StatelessWidget {
  const _Grupos({required this.grupos, this.onTap});

  final List<GrupoDeFotos> grupos;
  final void Function(ObraFoto)? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return ListView.builder(
      padding: EdgeInsets.all(spacing.md),
      itemCount: grupos.length,
      itemBuilder: (context, i) {
        final grupo = grupos[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) SizedBox(height: spacing.lg),
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Row(
                children: [
                  Icon(
                    grupo.tag == null
                        ? Icons.label_off_outlined
                        : etiquetaEnIcono(grupo.tag!),
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                  SizedBox(width: spacing.xs),
                  Text(
                    grupo.tag == null
                        ? l10n.photosGroupUntagged
                        : etiquetaEnTexto(grupo.tag!, l10n),
                    style: context.texts.titleSmall,
                  ),
                  SizedBox(width: spacing.xs),
                  Text(
                    '${grupo.fotos.length}',
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: spacing.sm,
                mainAxisSpacing: spacing.sm,
              ),
              itemCount: grupo.fotos.length,
              itemBuilder: (context, j) => _Miniatura(
                foto: grupo.fotos[j],
                onTap: onTap == null ? null : () => onTap!(grupo.fotos[j]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.foto, this.onTap});

  final ObraFoto foto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(spacing.radiusMd),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(spacing.radiusMd),
            child: foto.enElTelefono
                ? Image.file(File(foto.localPath!), fit: BoxFit.cover)
                // Sin el archivo local hace falta señal: se dice, no se muestra
                // un error ni un cuadro roto.
                : ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: Icon(Icons.cloud_outlined,
                          color: colors.onSurfaceVariant),
                    ),
                  ),
          ),
          // La etiqueta ya la dice el encabezado del grupo: acá solo va lo que
          // no se sabe de otra forma —que no subió, que falló, que ya salió.
          if (foto.fallida || !foto.subida || foto.visibility != 'INTERNAL')
            Positioned(
              left: spacing.xs,
              right: spacing.xs,
              bottom: spacing.xs,
              child: _Estado(foto: foto, l10n: l10n),
            ),
        ],
      ),
    );
  }
}

/// Lo que hay que saber de la foto sin abrirla, en una línea.
class _Estado extends StatelessWidget {
  const _Estado({required this.foto, required this.l10n});

  final ObraFoto foto;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (tono, texto, icono) = switch (foto) {
      _ when foto.fallida => (
          StatusTone.danger,
          l10n.photosUploadFailed,
          Icons.cloud_off_outlined
        ),
      _ when !foto.subida => (
          StatusTone.info,
          l10n.photosOnThisPhone,
          Icons.smartphone_outlined
        ),
      _ when foto.visibility == 'PUBLIC' => (
          StatusTone.success,
          l10n.photosVisibilityPublic,
          Icons.public
        ),
      _ when foto.visibility == 'CLIENT' => (
          StatusTone.info,
          l10n.photosVisibilityClient,
          Icons.visibility_outlined
        ),
      _ => (StatusTone.info, l10n.photosVisibilityInternal, Icons.lock_outline),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(context.spacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El icono lleva el color del tono: en una miniatura no hay relleno
          // que lo sostenga, y el color solo nunca alcanza.
          Icon(icono, size: 14, color: tono.color(context)),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              texto,
              style: context.texts.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

final fotosDeLaObraProvider =
    StreamProvider.family<List<ObraFoto>, String>((ref, projectId) {
  return ref.watch(mediaRepositoryProvider).watchDeLaObra(projectId);
});
