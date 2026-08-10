import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

/// Los tipos que el servidor acepta en un lote. Salen de `SYNC_OPERATIONS` del
/// contrato; si se agrega uno allá, se agrega acá.
abstract final class SyncOp {
  static const customerCreate = 'customer.create';
  static const customerUpdate = 'customer.update';
  static const siteCreate = 'site.create';
  static const projectCreate = 'project.create';
  static const projectUpdate = 'project.update';
}

/// La cola de lo que todavía no llegó al servidor.
///
/// Toda escritura de la app pasa por acá. **Nadie llama al API directo**: se
/// escribe en local, se encola, y el sincronizador se ocupa. Así la pantalla no
/// tiene que saber si hay señal.
class Outbox {
  const Outbox(this._db, this._uuid);

  final AppDatabase _db;
  final Uuid _uuid;

  /// Encola una operación y devuelve su clave.
  ///
  /// La clave es UUIDv7 del dispositivo y **no cambia entre reintentos**: es lo
  /// que hace que el servidor responda `duplicate` en vez de duplicar cuando la
  /// red se corta después de escribir (regla 19).
  Future<String> enqueue({
    required String type,
    required String targetId,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
    String? clientId,
  }) async {
    // Se puede fijar para volver a encolar algo que ya se había mandado: es la
    // misma clave, así que el servidor lo reconoce como repetido en vez de
    // aplicarlo dos veces.
    final clave = clientId ?? _uuid.v7();
    await _db.into(_db.outboxOperations).insert(
      OutboxOperationsCompanion.insert(
        clientId: clave,
        type: type,
        targetId: targetId,
        payload: jsonEncode(payload),
        // Cuándo lo hizo la persona, no cuándo se manda: el servidor ordena el
        // lote con esto, y una salida no puede aplicarse antes que su entrada.
        occurredAt: occurredAt ?? DateTime.now(),
      ),
    );
    return clave;
  }

  /// Lo pendiente, en el orden en que ocurrió.
  Future<List<OutboxOperation>> pending() {
    return (_db.select(_db.outboxOperations)
          ..orderBy([(o) => OrderingTerm.asc(o.occurredAt)]))
        .get();
  }

  /// Cuántas operaciones esperan. Para que la interfaz pueda decirlo.
  Stream<int> watchPendingCount() {
    return _db.outboxOperations.count().watchSingle();
  }

  /// Sale de la cola: el servidor la aplicó, o ya la tenía.
  Future<void> remove(String clientId) {
    return (_db.delete(_db.outboxOperations)
          ..where((o) => o.clientId.equals(clientId)))
        .go();
  }

  /// Falló pero se puede reintentar. Se guarda el motivo para poder mostrar por
  /// qué algo no sube, en vez de dejarlo desaparecer en silencio.
  Future<void> markFailed(String clientId, String? code) {
    return (_db.update(_db.outboxOperations)
          ..where((o) => o.clientId.equals(clientId)))
        .write(
          OutboxOperationsCompanion(
            attempts: const Value.absent(),
            lastError: Value(code),
          ),
        );
  }

  Future<void> incrementAttempts(String clientId) {
    return _db.customStatement(
      'UPDATE outbox_operations SET attempts = attempts + 1 WHERE client_id = ?',
      [clientId],
    );
  }
}

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final outboxProvider = Provider<Outbox>((ref) {
  return Outbox(ref.watch(appDatabaseProvider), ref.watch(uuidProvider));
});

/// Cuántas escrituras esperan señal. La interfaz lo usa para avisar.
final pendingCountProvider = StreamProvider<int>((ref) {
  return ref.watch(outboxProvider).watchPendingCount();
});
