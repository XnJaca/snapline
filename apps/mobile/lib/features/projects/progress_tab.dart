import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/project_status.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/field_action_button.dart';
import '../../data/repositories/progress_repository.dart';
import '../../l10n/app_localizations.dart';
import 'note_sheet.dart';
import 'photos_tab.dart';
import 'progress_history_screen.dart';
import 'project_status_display.dart';

/// Cómo va la obra, de un vistazo.
///
/// La pregunta que responde es **dónde está**, no qué pasó: el estado con su
/// escalera, el antes contra lo último, cuánto se trabajó y lo último que
/// alguien escribió. El hilo cronológico es la otra pregunta y vive detrás de un
/// toque, en [ProgressHistoryScreen].
class ProgressTab extends ConsumerWidget {
  const ProgressTab({
    super.key,
    required this.projectId,
    this.indiceDeDetalle = -1,
  });

  final String projectId;

  /// Dónde está la tab Detalle, para que el aviso de Etapas pueda llevar hasta
  /// su interruptor. `-1` cuando el rol no la ve: entonces el aviso informa y
  /// no ofrece una salida que no existe.
  final int indiceDeDetalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final resumen = ref.watch(resumenDeAvanceProvider(projectId));
    final permisos =
        ref.watch(sessionControllerProvider).value?.membership.permissions ??
            const <String>[];
    final puedeEscribir = permisos.contains('projects.write');

    return Column(
      children: [
        Expanded(
          child: switch (resumen) {
            AsyncData(:final value) when value.status.isEmpty => EmptyState(
                icon: Icons.trending_up,
                message: l10n.progressEmpty,
              ),
            AsyncData(:final value) => ListView(
                padding: EdgeInsets.fromLTRB(
                    spacing.lg, spacing.lg, spacing.lg, spacing.md),
                children: [
                  _Estado(resumen: value),
                  SizedBox(height: spacing.xl),
                  _ParDeFotos(resumen: value, projectId: projectId),
                  SizedBox(height: spacing.lg),
                  _Cifras(resumen: value),
                  if (value.ultimaNota != null) ...[
                    SizedBox(height: spacing.lg),
                    _UltimaNota(resumen: value),
                  ],
                  SizedBox(height: spacing.lg),
                  _AbrirHistorial(
                      projectId: projectId, cuantos: value.cuantosMovimientos),
                ],
              ),
            AsyncError() => EmptyState(
                icon: Icons.error_outline,
                message: l10n.progressEmpty,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        if (puedeEscribir)
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: FieldActionButton(
              icon: Icons.edit_outlined,
              label: l10n.progressWriteNote,
              onPressed: () => mostrarHojaDeNota(
                context,
                ref,
                projectId,
                irADetalle: indiceDeDetalle < 0
                    ? null
                    : () => DefaultTabController.of(context)
                        .animateTo(indiceDeDetalle),
              ),
            ),
          ),
      ],
    );
  }
}

/// El estado con su fecha, y la escalera del ciclo de vida.
///
/// **No hay porcentaje de avance y no lo va a haber**: nadie calcula «45% del
/// techo». Un número derivado de las etapas o de las horas es inventado, y
/// termina repitiéndose al cliente como si estuviera respaldado por algo.
class _Estado extends StatelessWidget {
  const _Estado({required this.resumen});

  final ResumenDeAvance resumen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _label(resumen.status, l10n),
                style: context.texts.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (resumen.statusDesde != null)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.xs),
                child: Text(
                  l10n.progressSince(resumen.statusDesde!),
                  style: context.texts.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.md),
        // Una obra cancelada no está en ningún punto del camino: ubicarla sobre
        // la escalera diría que todavía avanza.
        if (resumen.peldano != null) _Escalera(hasta: resumen.peldano!),
      ],
    );
  }
}

/// Hasta dónde llegó la obra en su ciclo.
///
/// Marca **posición, no historia**: de una obra anterior al historial de estados
/// no se sabe si pisó cada peldaño, y la escalera no lo afirma.
class _Escalera extends StatelessWidget {
  const _Escalera({required this.hasta});

  final int hasta;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final estados = context.statusColors;

    return Row(
      children: [
        for (var i = 0; i < escaleraDeEstados.length; i++) ...[
          if (i > 0) SizedBox(width: spacing.xs),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= hasta ? estados.success : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(spacing.radiusSm),
                  ),
                ),
                SizedBox(height: spacing.xs),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: spacing.xs, vertical: 1),
                  decoration: i == hasta
                      ? BoxDecoration(
                          color: estados.successContainer,
                          borderRadius:
                              BorderRadius.circular(spacing.radiusSm),
                        )
                      : null,
                  child: Text(
                    _label(escaleraDeEstados[i], l10n),
                    textAlign: TextAlign.center,
                    style: context.texts.labelSmall?.copyWith(
                      color: i == hasta
                          ? estados.onSuccessContainer
                          : colors.onSurfaceVariant,
                      fontWeight: i == hasta ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// El antes contra lo último.
///
/// Es la comparación que este producto existe para producir, y en una obra de
/// techo es directamente el argumento de venta. A la derecha va la **más
/// reciente**, no la etiquetada `AFTER`: esa recién existe cuando la obra
/// termina, y esta pantalla tiene que servir mientras dura.
class _ParDeFotos extends StatelessWidget {
  const _ParDeFotos({required this.resumen, required this.projectId});

  final ResumenDeAvance resumen;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Rotulo(texto: l10n.progressBeforeAndNow),
        SizedBox(height: spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: resumen.fotoDelAntes == null
                  ? const _FaltaElAntes()
                  : _Foto(
                      assetId: resumen.fotoDelAntes!,
                      que: l10n.photosTagBefore,
                      cuando: resumen.fechaDelAntes,
                      projectId: projectId,
                    ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: resumen.fotoMasReciente == null
                  ? const SizedBox.shrink()
                  : _Foto(
                      assetId: resumen.fotoMasReciente!,
                      que: l10n.progressLatestPhoto,
                      cuando: resumen.fechaMasReciente,
                      projectId: projectId,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Foto extends ConsumerWidget {
  const _Foto({
    required this.assetId,
    required this.que,
    required this.cuando,
    required this.projectId,
  });

  final String assetId;
  final String que;
  final DateTime? cuando;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;

    final fotos = ref.watch(fotosDeLaObraProvider(projectId)).value ?? const [];
    final coincidencias = fotos.where((f) => f.id == assetId);
    final foto = coincidencias.isEmpty ? null : coincidencias.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(spacing.radiusMd),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: foto == null
                ? ColoredBox(color: colors.surfaceContainerHighest)
                : FotoDeObra(foto: foto, fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: spacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                que,
                style: context.texts.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (cuando != null)
              Text(
                l10n.progressShortDate(cuando!),
                style: context.texts.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
          ],
        ),
      ],
    );
  }
}

/// El lado vacío cuando todavía no hay foto del antes.
///
/// Dice **cuándo** hay que sacarla, que es el dato que se pierde: una vez que la
/// cuadrilla empezó, el antes de esa obra ya no existe.
class _FaltaElAntes extends StatelessWidget {
  const _FaltaElAntes();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(spacing.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 20, color: colors.onSurfaceVariant),
            SizedBox(height: spacing.xs),
            Flexible(
              child: Text(
                l10n.progressNoBeforePhoto,
                style: context.texts.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuánto se trabajó, cuántos días y cuántas fotos.
///
/// Las horas **son una cifra, no una lista**: el desglose por día es de la tab
/// Horas, y repetirlo acá tapaba lo que la obra tiene para contar.
class _Cifras extends StatelessWidget {
  const _Cifras({required this.resumen});

  final ResumenDeAvance resumen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final trabajado = Duration(minutes: resumen.minutosTrabajados);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(spacing.radiusMd),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Cifra(
              numero: l10n.obrasDuration(
                  trabajado.inHours, trabajado.inMinutes % 60),
              que: l10n.progressWorked,
            ),
            _Separador(),
            _Cifra(
              numero: '${resumen.diasEnObra}',
              que: l10n.progressDaysOnSite,
            ),
            _Separador(),
            _Cifra(
              numero: '${resumen.cuantasFotos}',
              que: l10n.progressPhotoCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.numero, required this.que});

  final String numero;
  final String que;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: spacing.md, horizontal: spacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              numero,
              style: context.texts.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              que,
              textAlign: TextAlign.center,
              style: context.texts.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      VerticalDivider(width: 1, color: context.colors.outlineVariant);
}

class _UltimaNota extends StatelessWidget {
  const _UltimaNota({required this.resumen});

  final ResumenDeAvance resumen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;

    final firma = [
      if (resumen.autorDeLaNota != null) resumen.autorDeLaNota!,
      if (resumen.fechaDeLaNota != null)
        l10n.progressShortDate(resumen.fechaDeLaNota!),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Rotulo(texto: l10n.progressLastNote),
        SizedBox(height: spacing.sm),
        Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(spacing.radiusMd),
            border: Border(left: BorderSide(color: colors.primary, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(resumen.ultimaNota!, style: context.texts.bodyMedium),
              if (firma.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: spacing.xs),
                  child: Text(
                    firma,
                    style: context.texts.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AbrirHistorial extends StatelessWidget {
  const _AbrirHistorial({required this.projectId, required this.cuantos});

  final String projectId;
  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;

    return InkWell(
      borderRadius: BorderRadius.circular(spacing.radiusMd),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProgressHistoryScreen(projectId: projectId),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(spacing.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child:
                  Text(l10n.progressSeeHistory, style: context.texts.bodyLarge),
            ),
            Text(
              l10n.progressMovements(cuantos),
              style: context.texts.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: context.texts.labelLarge?.copyWith(
          color: context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
}

String _label(String status, AppLocalizations l10n) => ProjectStatus.values
    .firstWhere((e) => e.json == status, orElse: () => ProjectStatus.$unknown)
    .label(l10n);
