import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/media/media_paths.dart';
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
    final puedeBorrar = permisos.contains('media.delete');

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
                onTap: puedeEtiquetar || puedeCambiarNivel || puedeBorrar
                    ? (foto) => mostrarAccionesDeFoto(
                          context,
                          ref,
                          foto,
                          puedeEtiquetar: puedeEtiquetar,
                          puedeCambiarNivel: puedeCambiarNivel,
                          puedeBorrar: puedeBorrar,
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

    final etiquetas =
        await mostrarHojaDeEtiquetas(context, esFotoNueva: true);

    // Sin etiqueta no se registra: la foto se descarta con su archivo. Es la
    // única salida de la hoja además de guardar, y borra antes de que exista
    // fila, así que no hay nada que sincronizar.
    if (etiquetas == null || etiquetas.isEmpty) {
      await MediaPaths.descartar(resultado.path!);
      return;
    }
    if (!context.mounted) return;

    final sesion = ref.read(sessionControllerProvider).value;
    await ref.read(mediaRepositoryProvider).registerPhoto(
          projectId: projectId,
          filePath: resultado.path!,
          companyId: sesion?.membership.companyId,
          tags: etiquetas,
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
            child: Text(l10n.actionCancel),
          ),
          // Abre los ajustes de la app de verdad. Un botón que dice "Abrir
          // ajustes" y solo cierra el diálogo deja a la persona igual de
          // trabada, y acá tomar la foto es la pantalla entera.
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
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

    final marca = _marcaDe(foto, l10n);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(spacing.radiusMd),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(spacing.radiusMd),
            child: FotoDeObra(foto: foto, fit: BoxFit.cover),
          ),
          // Solo el icono: en un tercio de ancho no entra una palabra sin
          // cortarse, y un texto truncado no dice nada. El detalle está a un
          // toque, en la hoja.
          if (marca != null)
            Positioned(
              top: spacing.xs,
              right: spacing.xs,
              child: Tooltip(
                message: marca.$2,
                child: Container(
                  padding: EdgeInsets.all(spacing.xs),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(marca.$3, size: 16, color: marca.$1.color(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que hay que saber de la foto sin abrirla. `null` cuando no hay nada que
/// avisar: una foto interna y subida es el caso normal y no lleva marca.
(StatusTone, String, IconData)? _marcaDe(ObraFoto foto, AppLocalizations l10n) {
  if (foto.fallida) {
    return (StatusTone.danger, l10n.photosUploadFailed, Icons.cloud_off_outlined);
  }
  if (!foto.subida) {
    return (StatusTone.info, l10n.photosOnThisPhone, Icons.smartphone_outlined);
  }
  return switch (foto.visibility) {
    'PUBLIC' => (StatusTone.success, l10n.photosVisibilityPublic, Icons.public),
    'CLIENT' => (
        StatusTone.info,
        l10n.photosVisibilityClient,
        Icons.visibility_outlined
      ),
    _ => null,
  };
}

/// La foto, de donde esté.
///
/// El archivo local es lo que la hace visible sin señal, y es el único camino
/// mientras no haya subido. Cuando ya no está en el teléfono se pide una URL
/// firmada: el bucket no es público (ADR-0010), así que esto necesita red.
class FotoDeObra extends ConsumerWidget {
  const FotoDeObra({super.key, required this.foto, required this.fit});

  final ObraFoto foto;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (foto.enElTelefono) {
      return Image.file(File(foto.localPath!), fit: fit);
    }

    // Sin archivo y sin subir no hay de dónde sacarla: pasó por un cierre de
    // sesión, que limpia lo local, antes de que el binario llegara al servidor.
    if (!foto.subida) {
      return _Aviso(icono: Icons.image_not_supported_outlined, mensaje: AppLocalizations.of(context).photosMissingFile);
    }

    return switch (ref.watch(urlDeFotoProvider(foto.id))) {
      AsyncData(:final value) => Image.network(value, fit: fit),
      AsyncError() => _Aviso(
          icono: Icons.wifi_off_outlined,
          mensaje: AppLocalizations.of(context).photosNeedsNetwork,
        ),
      // Mientras llega la URL: el mismo fondo que el resto de los marcos, no
      // un hueco transparente que deja ver la grilla por debajo.
      _ => ColoredBox(color: context.colors.surfaceContainerHighest),
    };
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceContainerHighest,
      child: Center(
        child: Tooltip(
          message: mensaje,
          child: Icon(icono, color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// La URL firmada de una foto. Vive diez minutos del lado del servidor, así que
/// se vuelve a pedir sola cuando el provider se recrea.
final urlDeFotoProvider = FutureProvider.family<String, String>((ref, assetId) {
  return ref.watch(mediaRepositoryProvider).urlParaVer(assetId);
});

final fotosDeLaObraProvider =
    StreamProvider.family<List<ObraFoto>, String>((ref, projectId) {
  return ref.watch(mediaRepositoryProvider).watchDeLaObra(projectId);
});
