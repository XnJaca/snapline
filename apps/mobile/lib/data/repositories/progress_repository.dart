import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../local/tables.dart';
import '../sync/outbox.dart';

/// Cuántas entradas trae cada página del hilo.
///
/// Se pagina desde el primer día: una obra de seis meses son cientos de
/// entradas repartidas en cuatro tablas, y la consulta que las mezcla se pone
/// lenta mucho antes de que se note en una obra de prueba.
const entradasPorPagina = 50;

/// Qué clase de cosa pasó. El hilo las mezcla en un solo orden.
///
/// Las jornadas **no** están acá: el avance de la obra cuenta qué se hizo, no
/// quién fichó. Las horas tienen su propio tab, y en el hilo tapaban lo demás —
/// una obra con cinco días trabajados y dos fotos mostraba cinco filas de
/// fichaje y dos de obra.
enum TipoDeEntrada { origen, hito, nota, fotos }

/// Una entrada del hilo, lista para dibujar.
///
/// Las clases llegan aplanadas a propósito: la pantalla agrupa por día
/// sin saber de qué tabla salió cada una.
class EntradaDelHilo {
  const EntradaDelHilo({
    required this.id,
    required this.tipo,
    required this.cuando,
    this.fromStatus,
    this.toStatus,
    this.pendiente = false,
    this.autorMembershipId,
    this.autor,
    this.body,
    this.visibility,
    this.assetIds = const [],
    this.etiqueta = '',
    this.cuantasFotos = 0,
  });

  final String id;
  final TipoDeEntrada tipo;

  /// Cuándo pasó, no cuándo llegó: es la marca del dispositivo. Un cambio hecho
  /// sin señal hace días se ubica donde ocurrió, no al final.
  final DateTime cuando;

  // — hito
  final String? fromStatus;
  final String? toStatus;

  /// Todavía en la bandeja. Solo un hito o una nota pueden serlo.
  final bool pendiente;

  final String? autorMembershipId;

  /// El nombre de quien lo hizo. Sale de `people`, con `LEFT JOIN`: una entrada
  /// no se esconde porque su persona todavía no haya bajado.
  final String? autor;

  // — nota
  final String? body;
  final String? visibility;
  final List<String> assetIds;

  // — fotos del día

  /// `BEFORE`, `AFTER`, `PROBLEM`, `RECEIPT`, `DURING` o `DETAIL`. Vacía si la
  /// foto no lleva ninguna.
  final String etiqueta;

  final int cuantasFotos;

  EntradaDelHilo conOrigen(String? from) => EntradaDelHilo(
        id: id,
        tipo: tipo,
        cuando: cuando,
        fromStatus: from,
        toStatus: toStatus,
        pendiente: pendiente,
        autorMembershipId: autorMembershipId,
        autor: autor,
        body: body,
        visibility: visibility,
        assetIds: assetIds,
        etiqueta: etiqueta,
        cuantasFotos: cuantasFotos,
      );
}

/// El hilo de la obra: qué pasó y en qué orden.
///
/// Lee **solo de local**, como todo lo demás: las cuatro fuentes son tablas que
/// el pull ya baja, así que la pantalla no hace una sola llamada de red.
/// Los estados por los que pasa una obra, en orden. Es el camino, no la
/// historia: la escalera dice hasta dónde llegó, no que haya pisado cada uno.
///
/// `ON_HOLD` no es una etapa sino una pausa dentro de la ejecución, así que se
/// muestra en la posición de `IN_PROGRESS`. `CANCELLED` no está en el camino:
/// una obra cancelada no se ubica en ningún punto de él.
const escaleraDeEstados = [
  'LEAD',
  'ESTIMATED',
  'SCHEDULED',
  'IN_PROGRESS',
  'COMPLETED',
];

/// Cómo está la obra, que es lo que la tab Avance responde de un vistazo.
///
/// Todo sale de la base local: sin señal la pantalla se arma igual, con lo que
/// el teléfono tenga.
class ResumenDeAvance {
  const ResumenDeAvance({
    required this.status,
    this.statusDesde,
    this.fotoDelAntes,
    this.fotoMasReciente,
    this.fechaDelAntes,
    this.fechaMasReciente,
    this.minutosTrabajados = 0,
    this.diasEnObra = 0,
    this.cuantasFotos = 0,
    this.ultimaNota,
    this.autorDeLaNota,
    this.fechaDeLaNota,
    this.cuantosMovimientos = 0,
  });

  final String status;

  /// Desde cuándo está en este estado. Nulo si nadie registró la transición:
  /// una obra anterior al historial no sabe desde cuándo está donde está.
  final DateTime? statusDesde;

  /// La más vieja etiquetada `BEFORE`, y la más reciente de la obra —no la
  /// etiquetada `AFTER`, que recién existe al terminar y esta pantalla tiene
  /// que servir mientras la obra dura.
  final String? fotoDelAntes;
  final String? fotoMasReciente;
  final DateTime? fechaDelAntes;
  final DateTime? fechaMasReciente;

  final int minutosTrabajados;
  final int diasEnObra;
  final int cuantasFotos;

  final String? ultimaNota;
  final String? autorDeLaNota;
  final DateTime? fechaDeLaNota;

  /// Cuántas entradas tiene el hilo completo, para la línea que lo abre.
  final int cuantosMovimientos;

  /// En qué peldaño cae, o `null` si la obra está fuera del camino.
  int? get peldano => switch (status) {
        'ON_HOLD' => escaleraDeEstados.indexOf('IN_PROGRESS'),
        'CANCELLED' => null,
        _ => escaleraDeEstados.contains(status)
            ? escaleraDeEstados.indexOf(status)
            : null,
      };
}

/// Las fotos del marcaje no son material de la obra: son evidencia de que
/// alguien estaba parado ahí. El hilo y el resumen las excluyen igual.
const _noEsDelMarcaje = '''
      AND NOT EXISTS (
        SELECT 1 FROM time_entries t
         WHERE t.clock_in_photo_id = m.id OR t.clock_out_photo_id = m.id)''';

/// De las etiquetas de una foto, la que más dice de la obra. Un antes no se
/// pierde detrás de un detalle, y la foto no cae en dos grupos.
const _etiquetaPrincipal = '''
                   CASE
                     WHEN m.tags LIKE '%"BEFORE"%'  THEN 'BEFORE'
                     WHEN m.tags LIKE '%"AFTER"%'   THEN 'AFTER'
                     WHEN m.tags LIKE '%"PROBLEM"%' THEN 'PROBLEM'
                     WHEN m.tags LIKE '%"RECEIPT"%' THEN 'RECEIPT'
                     WHEN m.tags LIKE '%"DURING"%'  THEN 'DURING'
                     WHEN m.tags LIKE '%"DETAIL"%'  THEN 'DETAIL'
                     ELSE ''
                   END''';

class ProgressRepository {
  ProgressRepository(this._db, this._outbox, this._uuid);

  final AppDatabase _db;
  final Outbox _outbox;
  final Uuid _uuid;

  /// Cómo está la obra: lo que la tab Avance responde sin desplazarse.
  ///
  /// Una sola consulta con subconsultas escalares en vez de seis streams
  /// combinados: cada bloque de la pantalla es un dato agregado, y traerlos por
  /// separado significaría seis emisiones desfasadas para pintar una vista.
  Stream<ResumenDeAvance> watchResumen(String projectId) {
    final query = _db.customSelect(
      '''
      SELECT
        p.status AS status,
        (SELECT max(c.device_recorded_at) FROM project_status_changes c
          WHERE c.project_id = p.id AND c.deleted_at IS NULL
            AND c.to_status = p.status) AS status_desde,

        (SELECT m.id FROM media_assets m
          WHERE m.project_id = p.id AND m.deleted_at IS NULL
            AND m.kind = 'PHOTO' AND m.tags LIKE '%"BEFORE"%' $_noEsDelMarcaje
          ORDER BY coalesce(m.captured_at, m.updated_at) ASC LIMIT 1) AS antes,
        (SELECT min(coalesce(m.captured_at, m.updated_at)) FROM media_assets m
          WHERE m.project_id = p.id AND m.deleted_at IS NULL
            AND m.kind = 'PHOTO' AND m.tags LIKE '%"BEFORE"%' $_noEsDelMarcaje)
          AS antes_cuando,

        (SELECT m.id FROM media_assets m
          WHERE m.project_id = p.id AND m.deleted_at IS NULL
            AND m.kind = 'PHOTO' $_noEsDelMarcaje
          ORDER BY coalesce(m.captured_at, m.updated_at) DESC LIMIT 1) AS ultima,
        (SELECT max(coalesce(m.captured_at, m.updated_at)) FROM media_assets m
          WHERE m.project_id = p.id AND m.deleted_at IS NULL
            AND m.kind = 'PHOTO' $_noEsDelMarcaje) AS ultima_cuando,
        (SELECT count(*) FROM media_assets m
          WHERE m.project_id = p.id AND m.deleted_at IS NULL
            AND m.kind = 'PHOTO' $_noEsDelMarcaje) AS cuantas_fotos,

        -- Una jornada abierta no suma: se contaría desde el fichaje de entrada
        -- y el total crecería solo mientras la pantalla está abierta.
        (SELECT coalesce(sum(
             CASE WHEN clock_out_at IS NULL THEN 0
                  ELSE (clock_out_at - clock_in_at) / 60 - break_minutes END), 0)
           FROM time_entries
          WHERE project_id = p.id AND deleted_at IS NULL) AS minutos,
        (SELECT count(DISTINCT date(clock_in_at, 'unixepoch')) FROM time_entries
          WHERE project_id = p.id AND deleted_at IS NULL) AS dias,

        (SELECT u.body FROM project_updates u
          WHERE u.project_id = p.id AND u.deleted_at IS NULL
          ORDER BY coalesce(u.published_at, u.updated_at) DESC LIMIT 1) AS nota,
        (SELECT pe.name FROM project_updates u
           LEFT JOIN people pe ON pe.membership_id = u.author_membership_id
          WHERE u.project_id = p.id AND u.deleted_at IS NULL
          ORDER BY coalesce(u.published_at, u.updated_at) DESC LIMIT 1)
          AS nota_autor,
        (SELECT max(coalesce(u.published_at, u.updated_at)) FROM project_updates u
          WHERE u.project_id = p.id AND u.deleted_at IS NULL) AS nota_cuando,

        -- Lo que el hilo va a mostrar, contado con su mismo criterio: las fotos
        -- agrupan por día y etiqueta, el ancla cuenta como un movimiento más, y
        -- los cambios que siguen en la bandeja también — el hilo los pinta, así
        -- que si no se cuentan la tab promete menos filas de las que abre.
        (SELECT count(*) FROM outbox_operations
          WHERE type = ?2 AND target_id = p.id
            AND json_extract(payload, '\$.status') IS NOT NULL)
        + (SELECT count(*) FROM project_status_changes c
          WHERE c.project_id = p.id AND c.deleted_at IS NULL)
        + (SELECT count(*) FROM project_updates u
            WHERE u.project_id = p.id AND u.deleted_at IS NULL)
        + (SELECT count(*) FROM (
             SELECT 1 FROM media_assets m
              WHERE m.project_id = p.id AND m.deleted_at IS NULL
                AND m.kind = 'PHOTO' $_noEsDelMarcaje
              GROUP BY date(coalesce(m.captured_at, m.updated_at), 'unixepoch'),
                       $_etiquetaPrincipal))
        + (CASE WHEN p.created_at IS NOT NULL AND NOT EXISTS (
             SELECT 1 FROM project_status_changes o
              WHERE o.project_id = p.id AND o.from_status IS NULL
                AND o.deleted_at IS NULL) THEN 1 ELSE 0 END) AS movimientos
      FROM projects p
     WHERE p.id = ?1
      ''',
      variables: [
        Variable<String>(projectId),
        Variable<String>(SyncOp.projectUpdate),
      ],
      readsFrom: {
        _db.projects,
        _db.projectStatusChanges,
        _db.projectUpdates,
        _db.mediaAssets,
        _db.timeEntries,
        _db.people,
        _db.outboxOperations,
      },
    );

    return query.watchSingleOrNull().map((f) {
      if (f == null) return const ResumenDeAvance(status: '');

      DateTime? fecha(String columna) {
        final v = f.read<int?>(columna);
        return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }

      return ResumenDeAvance(
        status: f.read<String>('status'),
        statusDesde: fecha('status_desde'),
        fotoDelAntes: f.read<String?>('antes'),
        fechaDelAntes: fecha('antes_cuando'),
        fotoMasReciente: f.read<String?>('ultima'),
        fechaMasReciente: fecha('ultima_cuando'),
        minutosTrabajados: f.read<int>('minutos'),
        diasEnObra: f.read<int>('dias'),
        cuantasFotos: f.read<int>('cuantas_fotos'),
        ultimaNota: f.read<String?>('nota'),
        autorDeLaNota: f.read<String?>('nota_autor'),
        fechaDeLaNota: fecha('nota_cuando'),
        cuantosMovimientos: f.read<int>('movimientos'),
      );
    });
  }

  /// El hilo, ordenado y paginado **en la base**.
  ///
  /// Un `UNION ALL` y no varios streams combinados en Dart: si el corte se
  /// hiciera acá arriba habría que traer las tablas enteras en cada emisión y la
  /// paginación sería decorativa. Drift observa todas las tablas que la consulta
  /// toca y vuelve a emitir cuando cualquiera cambia, que es lo que hace que una
  /// nota escrita sin señal aparezca al instante.
  Stream<List<EntradaDelHilo>> watchHilo(
    String projectId, {
    int limite = entradasPorPagina,
  }) {
    final query = _db.customSelect(
      '''
      SELECT * FROM (
        SELECT 'origen' AS tipo, 'origen-' || p.id AS id, p.created_at AS cuando,
               NULL AS from_status, NULL AS to_status, NULL AS autor,
               NULL AS texto, NULL AS visibility, NULL AS ids,
               0 AS cuantas, 0 AS personas, 0 AS minutos, 0 AS abiertas,
               0 AS pendiente, NULL AS autor_nombre, NULL AS etiqueta
          FROM projects p
         WHERE p.id = ?1 AND p.created_at IS NOT NULL
           AND NOT EXISTS (
             SELECT 1 FROM project_status_changes o
              WHERE o.project_id = p.id AND o.from_status IS NULL
                AND o.deleted_at IS NULL)

        UNION ALL
        SELECT 'hito', c.id, c.device_recorded_at,
               c.from_status, c.to_status, c.changed_by_membership_id,
               NULL, NULL, NULL,
               0, 0, 0, 0,
               0, pe.name, NULL
          FROM project_status_changes c
          LEFT JOIN people pe ON pe.membership_id = c.changed_by_membership_id
         WHERE c.project_id = ?1 AND c.deleted_at IS NULL

        UNION ALL
        SELECT 'nota', u.id, coalesce(u.published_at, u.updated_at),
               NULL, NULL, u.author_membership_id,
               u.body, u.visibility, u.asset_ids,
               0, 0, 0, 0,
               CASE WHEN u.sync_status = 0 THEN 1 ELSE 0 END, pe.name, NULL
          FROM project_updates u
          LEFT JOIN people pe ON pe.membership_id = u.author_membership_id
         WHERE u.project_id = ?1 AND u.deleted_at IS NULL

        UNION ALL
        SELECT 'fotos', 'fotos-' || dia || '-' || etiqueta, ultima,
               NULL, NULL, NULL, NULL, NULL, ids, cuantas, 0, 0, 0, 0, NULL, etiqueta
          FROM (
            SELECT date(coalesce(m.captured_at, m.updated_at), 'unixepoch') AS dia,
                   count(*) AS cuantas,
                   max(coalesce(m.captured_at, m.updated_at)) AS ultima,
                   group_concat(m.id) AS ids,
                   $_etiquetaPrincipal AS etiqueta
              FROM media_assets m
             WHERE m.project_id = ?1 AND m.deleted_at IS NULL
               AND m.kind = 'PHOTO' $_noEsDelMarcaje
             GROUP BY dia, etiqueta
          )

        UNION ALL
        SELECT 'encolado', client_id, occurred_at,
               NULL, NULL, NULL, payload, NULL, NULL, 0, 0, 0, 0, 1, NULL, NULL
          FROM outbox_operations
         WHERE type = ?2 AND target_id = ?1
      )
      ORDER BY cuando DESC
      LIMIT ?3
      ''',
      variables: [
        Variable<String>(projectId),
        Variable<String>(SyncOp.projectUpdate),
        Variable<int>(limite),
      ],
      readsFrom: {
        _db.projects,
        _db.projectStatusChanges,
        _db.projectUpdates,
        _db.mediaAssets,
        _db.timeEntries,
        _db.outboxOperations,
        _db.people,
      },
    );

    return query.watch().map(_armar);
  }

  /// De la fila cruda a la entrada, resolviendo de dónde venía cada cambio que
  /// todavía está en la bandeja.
  List<EntradaDelHilo> _armar(List<QueryRow> filas) {
    final salida = <EntradaDelHilo>[];

    for (final f in filas) {
      final tipo = f.read<String>('tipo');
      final cuando =
          DateTime.fromMillisecondsSinceEpoch(f.read<int>('cuando') * 1000);

      if (tipo == 'encolado') {
        // Solo los cambios de estado: por `project.update` viaja también la
        // edición de la ficha, que no es un hito.
        final payload = jsonDecode(f.read<String>('texto'));
        if (payload is! Map || payload['status'] is! String) continue;
        salida.add(EntradaDelHilo(
          id: f.read<String>('id'),
          tipo: TipoDeEntrada.hito,
          cuando: cuando,
          toStatus: payload['status'] as String,
          pendiente: true,
        ));
        continue;
      }

      salida.add(switch (tipo) {
        // El ancla: la obra existe desde acá. Sin estado, porque de una obra
        // anterior al historial no se sabe con cuál nació.
        'origen' => EntradaDelHilo(
            id: f.read<String>('id'),
            tipo: TipoDeEntrada.origen,
            cuando: cuando,
          ),
        // Un hito sin `from` es el nacimiento de la obra y sí afirma su estado
        // inicial: lo escribió `create` en el momento.
        'hito' when f.read<String?>('from_status') == null => EntradaDelHilo(
            id: f.read<String>('id'),
            tipo: TipoDeEntrada.origen,
            cuando: cuando,
            toStatus: f.read<String?>('to_status'),
            autorMembershipId: f.read<String?>('autor'),
            autor: f.read<String?>('autor_nombre'),
          ),
        'hito' => EntradaDelHilo(
            id: f.read<String>('id'),
            tipo: TipoDeEntrada.hito,
            cuando: cuando,
            fromStatus: f.read<String?>('from_status'),
            toStatus: f.read<String?>('to_status'),
            autorMembershipId: f.read<String?>('autor'),
            autor: f.read<String?>('autor_nombre'),
          ),
        'nota' => EntradaDelHilo(
            id: f.read<String>('id'),
            tipo: TipoDeEntrada.nota,
            cuando: cuando,
            body: f.read<String?>('texto'),
            visibility: f.read<String?>('visibility'),
            autorMembershipId: f.read<String?>('autor'),
            autor: f.read<String?>('autor_nombre'),
            assetIds: _leerIds(f.read<String?>('ids')),
            pendiente: f.read<int>('pendiente') == 1,
          ),
        _ => EntradaDelHilo(
            id: f.read<String>('id'),
            tipo: TipoDeEntrada.fotos,
            cuando: cuando,
            etiqueta: f.read<String?>('etiqueta') ?? '',
            cuantasFotos: f.read<int>('cuantas'),
            // Las primeras cuatro alcanzan: la fila muestra una tira, no la
            // galería, que ya tiene su tab.
            assetIds: _separar(f.read<String?>('ids')).take(4).toList(),
          ),
      });
    }

    return _encadenar(salida);
  }

  /// De qué estado venía un cambio que todavía no llegó al servidor.
  ///
  /// La operación encolada lleva solo el estado nuevo, y el `status` local ya se
  /// sobrescribió al encolarla: el de partida sale del **hito inmediatamente
  /// anterior del hilo**. Con varios encolados se encadenan por su marca, que es
  /// el orden en que el servidor va a aplicarlos. En una obra anterior al
  /// historial puede no haber ninguno, y entonces el pendiente se muestra sin
  /// origen: de dónde venía es justamente lo que no se sabe.
  ///
  /// La lista viene en orden descendente, así que se recorre al revés: el
  /// anterior de cada pendiente es el último hito ya visto.
  List<EntradaDelHilo> _encadenar(List<EntradaDelHilo> entradas) {
    if (!entradas.any((e) => e.pendiente && e.tipo == TipoDeEntrada.hito)) {
      return entradas;
    }

    final salida = List<EntradaDelHilo>.from(entradas);
    String? anterior;
    for (var i = salida.length - 1; i >= 0; i--) {
      final e = salida[i];
      // El origen también cuenta: una obra nueva nace con su estado y el
      // primer cambio pendiente viene de ahí.
      if (e.tipo != TipoDeEntrada.hito && e.tipo != TipoDeEntrada.origen) {
        continue;
      }
      if (e.pendiente) {
        salida[i] = e.conOrigen(anterior);
      }
      anterior = e.toStatus ?? anterior;
    }
    return salida;
  }

  /// Escribe una nota. Nace local y se encola: la pantalla no espera a la red.
  ///
  /// `CLIENT` hace que el servidor la apruebe y publique en el mismo acto, y que
  /// eleve a `CLIENT` las fotos adjuntas que estén en `INTERNAL` — sin eso el
  /// portal entrega la nota sin sus fotos.
  Future<String> escribirNota({
    required String projectId,
    required String body,
    required String visibility,
    required String authorMembershipId,
    required String companyId,
    List<String> assetIds = const [],
    DateTime? occurredAt,
  }) async {
    final id = _uuid.v7();
    final cuando = occurredAt ?? DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.projectUpdates).insert(ProjectUpdatesCompanion.insert(
            id: id,
            companyId: companyId,
            updatedAt: cuando,
            projectId: projectId,
            authorMembershipId: authorMembershipId,
            body: body,
            visibility: visibility,
            publishedAt: Value(visibility == 'CLIENT' ? cuando : null),
            assetIds: Value(jsonEncode(assetIds)),
            syncStatus: const Value(SyncStatus.pending),
          ));
      await _outbox.enqueue(
        type: SyncOp.projectUpdateCreate,
        targetId: id,
        payload: {
          'projectId': projectId,
          'body': body,
          'visibility': visibility,
          if (assetIds.isNotEmpty) 'assetIds': assetIds,
        },
        occurredAt: cuando,
      );
    });

    return id;
  }

  List<String> _leerIds(String? json) {
    if (json == null || json.isEmpty) return const [];
    final decodificado = jsonDecode(json);
    if (decodificado is! List) return const [];
    return decodificado.whereType<String>().toList(growable: false);
  }

  List<String> _separar(String? concatenados) {
    if (concatenados == null || concatenados.isEmpty) return const [];
    return concatenados.split(',')..removeWhere((s) => s.isEmpty);
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxProvider),
    ref.watch(uuidProvider),
  );
});

/// Cómo está la obra, para la tab Avance.
final resumenDeAvanceProvider =
    StreamProvider.family<ResumenDeAvance, String>((ref, projectId) {
  return ref.watch(progressRepositoryProvider).watchResumen(projectId);
});

/// El hilo de una obra, con su tope de entradas.
final hiloDeLaObraProvider = StreamProvider.family<List<EntradaDelHilo>,
    ({String projectId, int limite})>((ref, args) {
  return ref
      .watch(progressRepositoryProvider)
      .watchHilo(args.projectId, limite: args.limite);
});
