import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../api/models/sync_operation_dto.dart';
import '../../api/models/sync_operation_dto_type.dart';
import '../../api/models/sync_pull_response_dto.dart';
import '../../api/models/sync_push_dto.dart';
import '../../api/models/sync_push_response_dto.dart';
import '../../api/models/sync_result_dto.dart';
import '../../api/models/sync_result_dto_status.dart';
import '../../api/clients/sync_client.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../local/app_database.dart';
import '../local/tables.dart';
import 'outbox.dart';
import 'sync_mapper.dart';

/// El único que habla con la red.
///
/// Las pantallas leen de Drift y escriben en Drift; esto trae lo del servidor y
/// empuja la bandeja. Sin señal la app funciona igual, solo que este de acá no
/// avanza.
class Synchronizer {
  Synchronizer(this._db, this._api, this._outbox);

  /// Un solo cursor: el pull es una foto de todo lo que cambió, no una por
  /// colección.
  static const _cursorId = 'pull';

  final AppDatabase _db;
  final SyncClient _api;
  final Outbox _outbox;

  /// Estos códigos —y solo estos— dejan una fila de `time_entry` en conflicto.
  ///
  /// La regla 12 no permite que unas horas se sobrescriban solas: acá se marcan
  /// y las mira un humano. Cualquier otro error es reintentable y **no** marca
  /// conflicto; sin esta lista, cada quien decidiría distinto qué es un
  /// conflicto justo en el agregado donde no se puede improvisar.
  static const conflictCodes = {
    'TIME_ENTRY_ALREADY_OPEN',
    'TIME_ENTRY_ALREADY_CLOSED',
    // Dos personas decidieron distinto sobre las mismas horas.
    'TIME_ENTRY_DECISION_CONFLICTS',
  };

  /// Los códigos que **descartan**: sacan la operación de la cola y devuelven la
  /// fila al estado que tenía antes de decidir.
  ///
  /// La causa está del lado del servidor y reenviar lo mismo falla igual, para
  /// siempre — la cola se llenaría de operaciones condenadas. Volver a decidir
  /// es un acto de la persona, con el estado nuevo a la vista.
  ///
  /// **La lista es cerrada a propósito**, como `conflictCodes`: hasta SPEC-0011
  /// ninguna operación salía de la cola sin haberse aplicado, y descartar
  /// trabajo real de alguien en silencio es peor que reintentar de más. Un
  /// código desconocido nunca descarta.
  static const discardCodes = {
    // El estado ya es el que se pidió: alguien decidió lo mismo desde otro lado.
    'TIME_ENTRY_DECISION_MATCHES',
    // La tarifa no baja al teléfono, así que esto no se puede prevenir acá.
    'PAY_RATE_MISSING',
    'TIME_ENTRY_STILL_OPEN',
    'CANNOT_APPROVE_OWN_HOURS',
  };

  /// De los que descartan, los que la pantalla tiene que explicar.
  ///
  /// `TIME_ENTRY_DECISION_MATCHES` no entra: el estado local ya coincide con el
  /// del servidor y no hay nada que contar. `CANNOT_APPROVE_OWN_HOURS` tampoco
  /// —es un bug de la app, no un problema de quien la usa— y queda en el log.
  static const reportedDiscardCodes = {
    'PAY_RATE_MISSING',
    'TIME_ENTRY_STILL_OPEN',
  };

  /// Manda lo pendiente y después trae lo nuevo.
  ///
  /// **El push va primero**: si se trajera antes, lo del servidor pisaría en
  /// local una corrección que todavía no se envió.
  Future<bool> sync() async {
    final subio = await push();
    final bajo = await pull();
    return subio && bajo;
  }

  /// Vacía la bandeja de salida en una sola llamada.
  ///
  /// Devuelve `false` si no se pudo hablar con el servidor. Que una operación
  /// del lote falle **no** es un fallo de la sincronización: las demás entraron
  /// y esa queda encolada con su motivo.
  Future<bool> push() => _outbox.exclusivo(_push);

  /// El push de verdad. Corre con el turno de la bandeja tomado: armar el lote,
  /// esperar la red y aplicar la respuesta son **un solo acto**, o una decisión
  /// encolada en el medio viajaría pidiendo un estado que el servidor ya cambió.
  Future<bool> _push() async {
    try {
      // Lo que quedó en conflicto no se reenvía: el servidor va a responder lo
      // mismo, y la regla 12 dice que lo resuelve un humano, no un reintento.
      // La operación sigue en la cola para que se vea — solo no viaja.
      final pendientes = (await _outbox.pending())
          .where((op) => !conflictCodes.contains(op.lastError))
          .toList();
      if (pendientes.isEmpty) return true;

      final respuesta = await _api.syncPush(
        body: SyncPushDto(
          operations: pendientes
              .map(
                (op) => SyncOperationDto(
                  clientId: op.clientId,
                  type: SyncOperationDtoType.fromJson(op.type),
                  targetId: op.targetId,
                  payload: jsonDecode(op.payload) as Map<String, Object?>,
                  occurredAt: op.occurredAt.toUtc().toIso8601String(),
                ),
              )
              .toList(),
        ),
      );

      await _aplicarResultados(respuesta);
      return true;
    } on ApiFailure catch (e, stack) {
      developer.log('push falló', name: 'sync', error: e, stackTrace: stack);
      return false;
    } catch (e, stack) {
      developer.log('push falló', name: 'sync', error: e, stackTrace: stack);
      return false;
    }
  }

  /// `duplicate` es éxito: la operación ya se había aplicado en un intento
  /// anterior y sale de la cola igual que si fuera nueva.
  Future<void> _aplicarResultados(SyncPushResponseDto respuesta) async {
    for (final resultado in respuesta.results) {
      final aplicada = resultado.status == SyncResultDtoStatus.applied ||
          resultado.status == SyncResultDtoStatus.duplicate;

      if (aplicada) {
        await _outbox.remove(resultado.clientId);
        await _marcarSincronizada(resultado.resourceId);
        continue;
      }

      if (discardCodes.contains(resultado.code)) {
        await _descartar(resultado);
        continue;
      }

      await _outbox.incrementAttempts(resultado.clientId);
      await _outbox.markFailed(resultado.clientId, resultado.code);

      if (conflictCodes.contains(resultado.code)) {
        // La fila local queda en CONFLICT y ahí se queda hasta que la mire un
        // humano: las horas de alguien no se sobrescriben solas (regla 12). La
        // operación queda en la cola igual — sale cuando se resuelva, no por
        // reintento.
        final operacion = await _outbox.byClientId(resultado.clientId);
        if (operacion != null) {
          await _db.customUpdate(
            'UPDATE time_entries SET sync_status = ? WHERE id = ?',
            variables: [
              Variable<int>(SyncStatus.conflict.index),
              Variable<String>(operacion.targetId),
            ],
            updates: {_db.timeEntries},
          );
        }
        developer.log(
          'conflicto en ${resultado.clientId}: ${resultado.code}',
          name: 'sync',
        );
      }
    }
  }

  /// La fila local pasa de `PENDING` a `SYNCED`. Es lo que apaga la marca de
  /// "guardado en el teléfono" en la pantalla.
  ///
  /// **Va con `customUpdate` y su `updates`, no con `customStatement`.** Drift no
  /// sabe qué tabla toca una sentencia cruda, así que no refresca ningún stream:
  /// la fila queda bien en la base y la pantalla sigue mostrando lo viejo hasta
  /// que alguien la reconstruya.
  Future<void> _marcarSincronizada(String? resourceId) async {
    if (resourceId == null) return;
    final tablas = <TableInfo<Table, dynamic>>[
      _db.customers,
      _db.sites,
      _db.projects,
      _db.timeEntries,
      _db.mediaAssets,
    ];
    for (final tabla in tablas) {
      await _db.customUpdate(
        'UPDATE ${tabla.actualTableName} SET sync_status = ? WHERE id = ?',
        variables: [
          Variable<int>(SyncStatus.synced.index),
          Variable<String>(resourceId),
        ],
        updates: {tabla},
      );
    }

    // La decisión llegó: se limpia su rastro local. Si quedara `decided_from`,
    // el próximo descarte revertiría a un estado ya viejo.
    await _db.customUpdate(
      'UPDATE time_entries SET decided_from = NULL, last_rejection = NULL '
      'WHERE id = ?',
      variables: [Variable<String>(resourceId)],
      updates: {_db.timeEntries},
    );
  }

  /// El servidor rechazó la decisión por algo que no se arregla reintentando:
  /// sale de la cola y la jornada vuelve al estado que tenía antes.
  ///
  /// **El estado anterior sale de `decided_from`, no del servidor.** El rechazo
  /// ocurre antes de cualquier escritura, así que `updated_at` no se movió y el
  /// pull incremental no vuelve a traer esta fila: esperarla dejaría la jornada
  /// mostrando "Aprobada" para siempre.
  ///
  /// `last_rejection` guarda el **código**; el texto lo arma la pantalla
  /// (regla 24).
  Future<void> _descartar(SyncResultDto resultado) async {
    final operacion = await _outbox.byClientId(resultado.clientId);
    await _outbox.remove(resultado.clientId);
    if (operacion == null) return;

    final reportable = reportedDiscardCodes.contains(resultado.code);
    await _db.customUpdate(
      'UPDATE time_entries SET status = coalesce(decided_from, status), '
      'decided_from = NULL, last_rejection = ?, sync_status = ? WHERE id = ?',
      variables: [
        Variable<String>(reportable ? resultado.code : null),
        Variable<int>(SyncStatus.synced.index),
        Variable<String>(operacion.targetId),
      ],
      updates: {_db.timeEntries},
    );
    developer.log(
      'decisión descartada en ${resultado.clientId}: ${resultado.code}',
      name: 'sync',
    );
  }

  /// Trae lo que cambió desde el último pull y lo escribe en local.
  ///
  /// Devuelve `false` si no se pudo —sin red, token vencido— y **no lanza**:
  /// que la sincronización falle nunca puede romper la pantalla que la disparó.
  Future<bool> pull() async {
    try {
      final desde = await _cursor();
      final respuesta = await _api.syncPull(since: desde?.toIso8601String());
      await _aplicar(respuesta);
      return true;
    } on ApiFailure catch (e, stack) {
      // Se registra pero no se propaga: sin señal la app tiene que seguir
      // andando. Silenciarlo del todo, en cambio, deja imposible entender por
      // qué una lista aparece vacía.
      developer.log('pull falló', name: 'sync', error: e, stackTrace: stack);
      return false;
    } catch (e, stack) {
      developer.log('pull falló', name: 'sync', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<DateTime?> _cursor() async {
    final fila = await (_db.select(
      _db.syncCursors,
    )..where((c) => c.id.equals(_cursorId))).getSingleOrNull();
    return fila?.serverTime;
  }

  /// Todo en una transacción: si algo falla a mitad, el cursor no avanza y el
  /// próximo pull vuelve a traer lo mismo. Media sincronización aplicada con el
  /// cursor movido dejaría un hueco que nadie vuelve a llenar.
  Future<void> _aplicar(SyncPullResponseDto respuesta) async {
    await _db.transaction(() async {
      for (final dto in respuesta.customers) {
        await _db.into(_db.customers).insertOnConflictUpdate(SyncMapper.customer(dto));
      }
      for (final dto in respuesta.sites) {
        await _db.into(_db.sites).insertOnConflictUpdate(SyncMapper.site(dto));
      }
      for (final dto in respuesta.projects) {
        await _db.into(_db.projects).insertOnConflictUpdate(SyncMapper.project(dto));
      }
      for (final dto in respuesta.assignments) {
        await _db
            .into(_db.projectAssignments)
            .insertOnConflictUpdate(SyncMapper.assignment(dto));
      }
      for (final dto in respuesta.timeEntries) {
        // Una fila local en CONFLICT no se pisa con lo del servidor: la mira
        // un humano primero (regla 12). Todo lo demás, última escritura gana.
        final local = await (_db.select(_db.timeEntries)
              ..where((t) => t.id.equals(dto.id)))
            .getSingleOrNull();
        if (local?.syncStatus == SyncStatus.conflict) continue;
        await _db.into(_db.timeEntries).insertOnConflictUpdate(SyncMapper.timeEntry(dto));
      }
      for (final dto in respuesta.mediaAssets) {
        // Una fila con cambios sin empujar no se pisa: la etiqueta que se acaba
        // de poner todavía no está en el servidor, y traerla de vuelta vacía la
        // borraría de la pantalla. Se resuelve sola cuando el push entre.
        final local = await (_db.select(_db.mediaAssets)
              ..where((m) => m.id.equals(dto.id)))
            .getSingleOrNull();
        if (local?.syncStatus == SyncStatus.pending) continue;
        await _db.into(_db.mediaAssets).insertOnConflictUpdate(SyncMapper.mediaAsset(dto));
      }
      for (final dto in respuesta.crews) {
        await _db.into(_db.crews).insertOnConflictUpdate(SyncMapper.crew(dto));
      }
      for (final dto in respuesta.crewMembers) {
        await _db.into(_db.crewMembers).insertOnConflictUpdate(SyncMapper.crewMember(dto));
      }
      for (final dto in respuesta.people) {
        await _db.into(_db.people).insertOnConflictUpdate(SyncMapper.person(dto));
      }
      for (final dto in respuesta.projectStatusChanges) {
        // Sin guarda de pendiente: el historial no se escribe local nunca. Lo
        // que todavía no llegó se pinta desde la bandeja, no desde acá.
        await _db
            .into(_db.projectStatusChanges)
            .insertOnConflictUpdate(SyncMapper.statusChange(dto));
      }
      for (final dto in respuesta.projectUpdates) {
        // Una nota recién escrita y todavía sin empujar no se pisa, igual que
        // las fotos: el servidor no la tiene y traerla de vuelta la borraría de
        // la pantalla.
        final local = await (_db.select(_db.projectUpdates)
              ..where((u) => u.id.equals(dto.id)))
            .getSingleOrNull();
        if (local?.syncStatus == SyncStatus.pending) continue;
        await _db
            .into(_db.projectUpdates)
            .insertOnConflictUpdate(SyncMapper.projectUpdate(dto));
      }

      await _marcarBorrados(respuesta.deleted);

      await _db.into(_db.syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion.insert(
          id: _cursorId,
          serverTime: respuesta.serverTime,
        ),
      );
    });
  }

  /// Se marcan, no se borran: un borrado duro no se puede propagar a un
  /// dispositivo que estuvo sin señal (regla 20).
  Future<void> _marcarBorrados(Map<String, List<String>> borrados) async {
    final ahora = DateTime.now();

    Future<void> marcar(String clave, TableInfo<Table, dynamic> tabla) async {
      final ids = borrados[clave];
      if (ids == null || ids.isEmpty) return;
      // Igual que arriba: sin `updates` la fila se marca borrada y la lista
      // sigue mostrándola hasta que se reconstruya la pantalla.
      await _db.customUpdate(
        'UPDATE ${tabla.actualTableName} SET deleted_at = ? '
        'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        variables: [
          Variable<int>(ahora.millisecondsSinceEpoch ~/ 1000),
          ...ids.map(Variable<String>.new),
        ],
        updates: {tabla},
      );
    }

    await marcar('customers', _db.customers);
    await marcar('sites', _db.sites);
    await marcar('projects', _db.projects);
    await marcar('assignments', _db.projectAssignments);
    await marcar('timeEntries', _db.timeEntries);
    await marcar('mediaAssets', _db.mediaAssets);
    await marcar('crews', _db.crews);
    await marcar('crewMembers', _db.crewMembers);
    await marcar('projectStatusChanges', _db.projectStatusChanges);
    await marcar('projectUpdates', _db.projectUpdates);

    // `people` es una proyección: su baja se aplica borrando la fila. No hay
    // otro dispositivo al que propagar este borrado — la fuente es el pull.
    final bajasDeGente = borrados['people'];
    if (bajasDeGente != null && bajasDeGente.isNotEmpty) {
      await (_db.delete(_db.people)
            ..where((p) => p.membershipId.isIn(bajasDeGente)))
          .go();
    }
  }
}

final synchronizerProvider = Provider<Synchronizer>((ref) {
  return Synchronizer(
    ref.watch(appDatabaseProvider),
    ref.watch(syncClientProvider),
    ref.watch(outboxProvider),
  );
});
