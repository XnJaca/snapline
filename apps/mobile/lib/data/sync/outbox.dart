import 'dart:async';
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
  static const siteUpdate = 'site.update';
  static const projectCreate = 'project.create';
  static const projectUpdate = 'project.update';
  static const timeEntryClockIn = 'timeEntry.clockIn';
  static const timeEntryClockOut = 'timeEntry.clockOut';
  static const timeEntryApprove = 'timeEntry.approve';
  static const timeEntryReject = 'timeEntry.reject';
  static const mediaRegister = 'media.register';
  static const mediaTag = 'media.tag';
  static const mediaDelete = 'media.delete';
}

/// La cola de lo que todavía no llegó al servidor.
///
/// Toda escritura de la app pasa por acá. **Nadie llama al API directo**: se
/// escribe en local, se encola, y el sincronizador se ocupa. Así la pantalla no
/// tiene que saber si hay señal.
class Outbox {
  Outbox(this._db, this._uuid);

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

    await _db.transaction(() async {
      await _db.into(_db.outboxOperations).insert(
        OutboxOperationsCompanion.insert(
          clientId: clave,
          type: type,
          targetId: targetId,
          payload: jsonEncode(payload),
          // Cuándo lo hizo la persona, no cuándo se manda: el servidor ordena el
          // lote con esto, y una salida no puede aplicarse antes que su entrada.
          occurredAt: await _instanteMonotono(occurredAt ?? DateTime.now()),
        ),
      );
    });

    return clave;
  }

  /// El instante de la operación, corrido lo mínimo para que no empate con otra
  /// que ya esté en la cola.
  ///
  /// Crear un cliente y su propiedad en el mismo toque las deja en el mismo
  /// milisegundo, y **el servidor ordena el lote por `occurredAt`**: con empate
  /// puede aplicar la propiedad antes que su cliente y rechazarla por cliente
  /// inexistente. Un desempate local no alcanzaría, porque el que ordena de
  /// verdad es el otro lado.
  ///
  /// **El paso es de un segundo porque la columna guarda segundos enteros.**
  /// Drift persiste un `DateTime` como epoch en segundos, así que sumar
  /// milisegundos deja el mismo valor guardado: el bucle tenía que dar hasta mil
  /// vueltas —medidas 916ms para tres operaciones del mismo toque— para cruzar al
  /// segundo siguiente. Con paso de un segundo son tres consultas.
  ///
  /// Solo se toca el empate exacto: una operación que ocurrió antes que otra ya
  /// encolada conserva su instante y se aplica primero, que es lo que hace que
  /// una salida no pueda aplicarse antes que su entrada.
  ///
  /// El corrimiento llega al `deviceRecordedAt` de un marcaje, que va con este
  /// mismo campo. Es aceptable porque solo se corre lo que ya estaba empatado al
  /// segundo, y dos cosas que una persona hizo de verdad no caen en el mismo.
  Future<DateTime> _instanteMonotono(DateTime propuesto) async {
    var candidato = propuesto;
    while (await _ocupado(candidato)) {
      candidato = candidato.add(const Duration(seconds: 1));
    }
    return candidato;
  }

  Future<bool> _ocupado(DateTime instante) async {
    final fila = await (_db.select(_db.outboxOperations)
          ..where((o) => o.occurredAt.equals(instante))
          ..limit(1))
        .getSingleOrNull();
    return fila != null;
  }

  /// Lo pendiente, en el orden en que ocurrió.
  ///
  /// No hay dos filas con el mismo `occurredAt` —lo garantiza `enqueue`— así que
  /// este orden es total. El `clientId` queda como desempate por si una fila
  /// vieja de antes de esa garantía sigue en la cola.
  Future<List<OutboxOperation>> pending() {
    return (_db.select(_db.outboxOperations)
          ..orderBy([
            (o) => OrderingTerm.asc(o.occurredAt),
            (o) => OrderingTerm.asc(o.clientId),
          ]))
        .get();
  }

  /// Cuántas operaciones esperan. Para que la interfaz pueda decirlo.
  Stream<int> watchPendingCount() {
    return _db.outboxOperations.count().watchSingle();
  }

  /// Una operación puntual, para saber a qué fila apuntaba un resultado.
  Future<OutboxOperation?> byClientId(String clientId) {
    return (_db.select(_db.outboxOperations)
          ..where((o) => o.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  /// Sale de la cola: el servidor la aplicó, o ya la tenía.
  Future<void> remove(String clientId) {
    return (_db.delete(_db.outboxOperations)
          ..where((o) => o.clientId.equals(clientId)))
        .go();
  }

  /// Corre [accion] sin que se solape con otra que también tome el turno.
  ///
  /// **Lo que protege es el intervalo entre leer la cola y aplicar su
  /// respuesta.** `push()` arma el lote en memoria y después espera a la red;
  /// una decisión encolada en ese hueco no puede sustituir a la que ya viajó, y
  /// terminaría pidiéndole al servidor un estado que él acaba de cambiar. Con el
  /// turno, o la decisión entra antes de que el lote se arme, o entra después de
  /// saber en qué quedó.
  ///
  /// La escritura local **no** pasa por acá: la pantalla responde al instante,
  /// como siempre. Lo que espera es el encolado.
  Future<T> exclusivo<T>(Future<T> Function() accion) {
    final anterior = _turno;
    final propio = Completer<void>();
    _turno = propio.future;
    return anterior.then((_) => accion()).whenComplete(propio.complete);
  }

  Future<void> _turno = Future.value();

  /// Saca de la cola las operaciones de estos tipos que todavía apuntan a esa
  /// fila, y dice cuántas eran.
  ///
  /// **Es para sustituir una intención, no para descartar trabajo.** Se usa
  /// cuando una operación nueva deja sin sentido a la anterior sobre el mismo
  /// registro: decidir dos veces sobre la misma jornada antes de que la primera
  /// salga. Mandar las dos haría que el servidor aplicara la primera y rechazara
  /// la segunda —que es la que la persona quiso— y la jornada terminaría con la
  /// decisión descartada.
  Future<int> replacePending(String targetId, Set<String> types) {
    return (_db.delete(_db.outboxOperations)
          ..where((o) => o.targetId.equals(targetId) & o.type.isIn(types)))
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
