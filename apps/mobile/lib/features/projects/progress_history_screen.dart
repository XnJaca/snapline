import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/project_status.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/progress_repository.dart';
import '../../l10n/app_localizations.dart';
import 'photos_tab.dart';
import 'project_status_display.dart';

/// Todo lo que pasó en la obra, en un solo orden.
///
/// Es la otra pregunta: la tab Avance dice **cómo está** y esta pantalla dice
/// **qué pasó**. Se llega desde ahí, y por eso no repite ni el estado ni las
/// cifras — quien entra acá ya los vio.
///
/// **Sin cajas.** El borde, el relleno y el radio dicen "objeto aparte", y
/// estampados en cada entrada aplanan la jerarquía en vez de crearla: acá la dan
/// la columna de fechas y el peso del texto. Lo único con fondo es la nota, que
/// es texto que alguien escribió y se lee como cita.
class ProgressHistoryScreen extends ConsumerStatefulWidget {
  const ProgressHistoryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProgressHistoryScreen> createState() =>
      _ProgressHistoryScreenState();
}

class _ProgressHistoryScreenState extends ConsumerState<ProgressHistoryScreen> {
  /// Cuántas entradas se piden. Crece de a una página al llegar al final: el
  /// corte lo hace la base, no esta lista.
  int _limite = entradasPorPagina;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final hilo = ref.watch(
      hiloDeLaObraProvider((projectId: widget.projectId, limite: _limite)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressHistoryTitle)),
  body: switch (hilo) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
            icon: Icons.timeline,
            message: l10n.progressEmpty,
          ),
        AsyncData(:final value) => NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              final m = n.metrics;
              // Solo cuando la página que se pidió llegó llena: si vino
              // corta, ya no hay más atrás y pedir de nuevo es en vano.
              if (m.pixels >= m.maxScrollExtent - 200 &&
                  value.length >= _limite) {
                setState(() => _limite += entradasPorPagina);
              }
              return false;
            },
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  spacing.lg, spacing.lg, spacing.lg, spacing.md),
              itemCount: value.length,
              itemBuilder: (context, i) => _Entrada(
                entrada: value[i],
                // El día se escribe solo cuando cambia respecto de la
                // anterior: repetirlo en cada fila convierte el hilo en una
                // lista de fechas.
                diaNuevo: i == 0 ||
                    !_mismoDia(value[i - 1].cuando, value[i].cuando),
                primera: i == 0,
                ultima: i == value.length - 1,
                projectId: widget.projectId,
              ),
            ),
          ),
        AsyncError() => EmptyState(
            icon: Icons.error_outline,
            message: l10n.progressEmpty,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Una fila del hilo: cuándo a la izquierda, qué a la derecha.
///
/// **La fecha es una columna, no un encabezado.** Antes iba suelta arriba de
/// cada entrada, y como casi cada una cae en un día distinto el hilo terminaba
/// siendo una lista de fechas con contenido intercalado. Fija a la izquierda se
/// escanea de un vistazo, y no se repite cuando dos entradas comparten el día.
class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.entrada,
    required this.diaNuevo,
    required this.primera,
    required this.ultima,
    required this.projectId,
  });

  final EntradaDelHilo entrada;
  final bool diaNuevo;
  final bool primera;
  final bool ultima;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La línea separa días, no filas: dos entradas del mismo día quedan del
        // mismo lado y se leen como lo que son, cosas que pasaron juntas.
        if (diaNuevo && !primera) ...[
          Divider(height: 1, color: context.colors.outlineVariant),
          SizedBox(height: spacing.md),
        ],
        Padding(
          padding: EdgeInsets.only(bottom: ultima ? 0 : spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _anchoDeLaFecha,
                child: diaNuevo ? _Dia(cuando: entrada.cuando) : null,
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: switch (entrada.tipo) {
                  TipoDeEntrada.origen => _Origen(entrada: entrada),
                  TipoDeEntrada.hito => _Hito(entrada: entrada),
                  TipoDeEntrada.nota =>
                    _Nota(entrada: entrada, projectId: projectId),
                  TipoDeEntrada.fotos =>
                    _Fotos(entrada: entrada, projectId: projectId),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// El ancho de la columna de fechas. Fijo a propósito: si cada fila midiera su
/// propia fecha, la columna se movería y dejaría de leerse como columna.
const double _anchoDeLaFecha = 64;

/// La fecha de una entrada.
///
/// Lo reciente va en palabras —«hoy», «ayer»— porque es como se piensa un día
/// de obra; más atrás, la fecha corta. El año solo aparece cuando no es el
/// corriente: repetirlo en cada fila de una obra de este año es ruido.
class _Dia extends StatelessWidget {
  const _Dia({required this.cuando});

  final DateTime cuando;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final hoy = DateTime.now();
    final dias = DateTime(hoy.year, hoy.month, hoy.day)
        .difference(DateTime(cuando.year, cuando.month, cuando.day))
        .inDays;

    final texto = switch (dias) {
      0 => l10n.progressToday,
      1 => l10n.progressYesterday,
      _ when cuando.year != hoy.year => l10n.progressDateWithYear(cuando),
      _ => l10n.progressShortDate(cuando),
    };

    return Text(
      texto,
      style: context.texts.bodySmall?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Un cambio de estado.
///
/// El de origen va **sin flecha**: no afirma una transición, dice dónde empieza
/// lo registrado. Y si además lo sembró la migración, lo dice — esa fila no
/// atestigua que la obra haya nacido en ese estado.
/// El ancla del hilo: desde cuándo existe la obra.
///
/// Sin estado si la obra es anterior al historial —no se sabe con cuál nació—, y
/// con él si lo escribió `create` en el momento.
class _Origen extends StatelessWidget {
  const _Origen({required this.entrada});

  final EntradaDelHilo entrada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined,
                size: 17, color: context.colors.onSurfaceVariant),
            SizedBox(width: context.spacing.xs),
            Expanded(
              child: Text(
                entrada.toStatus == null
                    ? l10n.progressCreated
                    : l10n.progressOrigin(_nombre(entrada.toStatus, l10n)),
                style: context.texts.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        _Autor(entrada: entrada),
      ],
    );
  }
}

class _Hito extends StatelessWidget {
  const _Hito({required this.entrada});

  final EntradaDelHilo entrada;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final texts = context.texts;
    final origen = entrada.fromStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.arrow_forward,
                size: 17, color: colors.onSurfaceVariant),
            SizedBox(width: context.spacing.xs),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  if (origen != null)
                    TextSpan(
                      text: '${_nombre(origen, l10n)} → ',
                      style: texts.bodyLarge
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  TextSpan(
                    text: _nombre(entrada.toStatus, l10n),
                    style:
                        texts.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
          ],
        ),
        _Autor(entrada: entrada),
        if (entrada.pendiente)
          StatusLine(tone: StatusTone.info, label: l10n.progressNotSynced),
      ],
    );
  }
}

/// Lo que alguien escribió. Lo único del hilo con fondo propio.
class _Nota extends StatelessWidget {
  const _Nota({required this.entrada, required this.projectId});

  final EntradaDelHilo entrada;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: spacing.md, vertical: spacing.sm + 2),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(spacing.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entrada.body ?? '', style: context.texts.bodyLarge),
              if (entrada.assetIds.isNotEmpty) ...[
                SizedBox(height: spacing.sm),
                _Tira(assetIds: entrada.assetIds, lado: 44, projectId: projectId),
              ],
              _Autor(entrada: entrada),
            ],
          ),
        ),
        // Una nota interna no lleva marca: es el caso normal y no se anuncia.
        // La que sí la lleva es la que sale de la empresa.
        if (entrada.visibility == 'CLIENT')
          StatusLine(
            tone: StatusTone.info,
            label: l10n.photosVisibilityClient,
          ),
        if (entrada.pendiente)
          StatusLine(tone: StatusTone.info, label: l10n.progressNotSynced),
      ],
    );
  }
}

class _Fotos extends StatelessWidget {
  const _Fotos({required this.entrada, required this.projectId});

  final EntradaDelHilo entrada;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final etiqueta = _etiqueta(entrada.etiqueta, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Con etiqueta manda la etiqueta: que sean el antes de la obra dice más
        // que que sean tres. Sin ella queda el conteo solo.
        _Cabecera(
          icono: Icons.photo_camera_outlined,
          titulo: etiqueta ?? l10n.progressPhotos(entrada.cuantasFotos),
          detalle: etiqueta == null
              ? null
              : l10n.progressPhotos(entrada.cuantasFotos),
        ),
        SizedBox(height: spacing.sm),
        _Tira(assetIds: entrada.assetIds, lado: 52, projectId: projectId),
      ],
    );
  }

  /// El nombre de la etiqueta, reusando el del tab de Fotos: la misma foto no
  /// puede llamarse distinto en dos pantallas.
  static String? _etiqueta(String tag, AppLocalizations l10n) => switch (tag) {
        'BEFORE' => l10n.photosTagBefore,
        'AFTER' => l10n.photosTagAfter,
        'DURING' => l10n.photosTagDuring,
        'DETAIL' => l10n.photosTagDetail,
        'PROBLEM' => l10n.photosTagProblem,
        'RECEIPT' => l10n.photosTagReceipt,
        _ => null,
      };
}


/// El título de una fila que lleva a otra parte, con su chevrón.
/// La primera línea de una entrada: lo que la nombra, y lo que la cuantifica
/// atenuado detrás. Sin esa diferencia de peso las filas se leen todas iguales.
/// La primera línea de una entrada: su icono, lo que la nombra, y lo que la
/// cuantifica atenuado detrás.
///
/// El icono va acá y no en un riel aparte: es lo que distingue una nota de un
/// grupo de fotos de un cambio de estado, y a media línea de distancia del
/// texto se lee junto con él.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.titulo, this.detalle, this.icono});

  final String titulo;
  final String? detalle;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;

    return Row(
      children: [
        if (icono != null) ...[
          Icon(icono, size: 17, color: colors.onSurfaceVariant),
          SizedBox(width: context.spacing.xs),
        ],
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: titulo,
                style: texts.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (detalle != null)
                TextSpan(
                  text: '  $detalle',
                  style:
                      texts.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
            ]),
          ),
        ),
        Icon(Icons.chevron_right,
            size: 20, color: colors.onSurfaceVariant.withValues(alpha: .5)),
      ],
    );
  }
}

class _Autor extends StatelessWidget {
  const _Autor({required this.entrada});

  final EntradaDelHilo entrada;

  @override
  Widget build(BuildContext context) {
    final nombre = entrada.autor;
    if (nombre == null || nombre.isEmpty) return const SizedBox.shrink();

    return Text(
      nombre,
      style: context.texts.bodySmall
          ?.copyWith(color: context.colors.onSurfaceVariant),
    );
  }
}

/// Las miniaturas de una fila. No es la galería: eso ya tiene su tab.
class _Tira extends StatelessWidget {
  const _Tira({
    required this.assetIds,
    required this.lado,
    required this.projectId,
  });

  final List<String> assetIds;
  final double lado;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SizedBox(
      height: lado,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: assetIds.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.xs + 2),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(context.spacing.radiusSm),
          child: SizedBox(
            width: lado,
            height: lado,
            child: _Miniatura(assetId: assetIds[i], projectId: projectId),
          ),
        ),
      ),
    );
  }
}

/// La miniatura sale del mismo stream que la galería: una consulta menos, y
/// una foto que todavía no subió se ve igual porque su archivo está local.
class _Miniatura extends ConsumerWidget {
  const _Miniatura({required this.assetId, required this.projectId});

  final String assetId;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos = ref.watch(fotosDeLaObraProvider(projectId)).value ?? const [];
    final coincidencias = fotos.where((f) => f.id == assetId);
    final foto = coincidencias.isEmpty ? null : coincidencias.first;
    if (foto == null) {
      return ColoredBox(color: context.colors.surfaceContainerHighest);
    }
    return FotoDeObra(foto: foto, fit: BoxFit.cover);
  }
}

String _nombre(String? status, AppLocalizations l10n) {
  final valor = ProjectStatus.values.firstWhere(
    (s) => s.json == status,
    orElse: () => ProjectStatus.$unknown,
  );
  return valor.label(l10n);
}
