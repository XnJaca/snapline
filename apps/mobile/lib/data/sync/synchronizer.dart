import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/sync_pull_response_dto.dart';
import '../../api/clients/sync_client.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../local/app_database.dart';
import 'sync_mapper.dart';

/// El único que habla con la red.
///
/// Las pantallas leen de Drift y escriben en Drift; esto trae lo del servidor y
/// empuja la bandeja. Sin señal la app funciona igual, solo que este de acá no
/// avanza.
class Synchronizer {
  Synchronizer(this._db, this._api);

  /// Un solo cursor: el pull es una foto de todo lo que cambió, no una por
  /// colección.
  static const _cursorId = 'pull';

  final AppDatabase _db;
  final SyncClient _api;

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
      await _db.customStatement(
        'UPDATE ${tabla.actualTableName} SET deleted_at = ? '
        'WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        [ahora.millisecondsSinceEpoch ~/ 1000, ...ids],
      );
    }

    await marcar('customers', _db.customers);
    await marcar('sites', _db.sites);
    await marcar('projects', _db.projects);
    await marcar('assignments', _db.projectAssignments);
  }
}

final synchronizerProvider = Provider<Synchronizer>((ref) {
  return Synchronizer(
    ref.watch(appDatabaseProvider),
    ref.watch(syncClientProvider),
  );
});
