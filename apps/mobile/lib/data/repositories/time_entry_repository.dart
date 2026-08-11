import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../local/tables.dart';
import '../sync/outbox.dart';

/// Una jornada como la muestran las pantallas.
class TimeEntrySummary {
  const TimeEntrySummary({
    required this.id,
    required this.projectId,
    required this.membershipId,
    required this.recordedByMembershipId,
    required this.clockInAt,
    required this.clockOutAt,
    required this.breakMinutes,
    required this.method,
    required this.status,
    required this.flags,
    required this.syncStatus,
  });

  final String id;
  final String projectId;
  final String membershipId;
  final String recordedByMembershipId;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final int breakMinutes;
  final String method;
  final String status;
  final List<String> flags;
  final SyncStatus syncStatus;

  bool get abierta => clockOutAt == null;
  bool get enConflicto => syncStatus == SyncStatus.conflict;
  bool get pendiente => syncStatus != SyncStatus.synced;
}

/// Lo que el marcaje logró capturar. Todo opcional menos la hora: la escalera
/// de evidencia decide qué se pide, nunca qué se permite (regla 9).
class ClockEvidence {
  const ClockEvidence({
    this.lat,
    this.lng,
    this.accuracyM,
    this.photoId,
    this.isMockLocation = false,
    this.recordedOffline = true,
  });

  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? photoId;
  final bool isMockLocation;

  /// `true` salvo que se sepa lo contrario: se escribe primero en local y la
  /// red viene después, así que "offline" es el camino normal.
  final bool recordedOffline;
}

/// La puerta de las pantallas al marcaje.
///
/// **Escribe en Drift y encola. Nunca falla**: sin red, sin GPS, sin permiso de
/// cámara, la fila queda y el cronómetro arranca (regla 9). Lo que el servidor
/// tenga para decir llega después, por la sincronización.
class TimeEntryRepository {
  const TimeEntryRepository(this._db, this._outbox, this._uuid);

  final AppDatabase _db;
  final Outbox _outbox;
  final Uuid _uuid;

  // ─── Lectura ───────────────────────────────────────────────────────────────

  /// La jornada abierta de una persona, si hay. Es lo que decide si la pantalla
  /// muestra "marcar entrada" o el cronómetro con "marcar salida".
  Stream<TimeEntrySummary?> watchOpen(String membershipId) {
    return (_db.select(_db.timeEntries)
          ..where(
            (t) =>
                t.membershipId.equals(membershipId) &
                t.clockOutAt.isNull() &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.clockInAt)])
          ..limit(1))
        .watchSingleOrNull()
        .map((fila) => fila == null ? null : _resumen(fila));
  }

  /// Las jornadas desde una fecha, más recientes primero. "Mi semana".
  Stream<List<TimeEntrySummary>> watchSince(
    String membershipId,
    DateTime desde,
  ) {
    return (_db.select(_db.timeEntries)
          ..where(
            (t) =>
                t.membershipId.equals(membershipId) &
                t.clockInAt.isBiggerOrEqualValue(desde) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.clockInAt)]))
        .watch()
        .map((filas) => filas.map(_resumen).toList(growable: false));
  }

  /// Las jornadas en conflicto. Se muestran y las resuelve un humano; ninguna
  /// pantalla puede resolverlas sola (regla 12).
  Stream<List<TimeEntrySummary>> watchConflicts() {
    return (_db.select(_db.timeEntries)
          ..where(
            (t) =>
                t.syncStatus.equalsValue(SyncStatus.conflict) &
                t.deletedAt.isNull(),
          ))
        .watch()
        .map((filas) => filas.map(_resumen).toList(growable: false));
  }

  // ─── Escritura ─────────────────────────────────────────────────────────────

  /// Marca la entrada y devuelve el id de la jornada.
  ///
  /// `paraMembershipId` distinto del propio es marcar por otro; el servidor
  /// decide la bandera — el móvil no replica ese criterio, solo manda quién.
  Future<String> clockIn({
    required String projectId,
    required String membershipId,
    required String recordedByMembershipId,
    required String companyId,
    ClockEvidence evidence = const ClockEvidence(),
    DateTime? occurredAt,
  }) async {
    final id = _uuid.v7();
    final cuando = occurredAt ?? DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.timeEntries).insert(
        TimeEntriesCompanion.insert(
          id: id,
          companyId: companyId,
          updatedAt: cuando,
          syncStatus: const Value(SyncStatus.pending),
          projectId: projectId,
          membershipId: membershipId,
          recordedByMembershipId: recordedByMembershipId,
          clockInAt: cuando,
          method: membershipId == recordedByMembershipId ? 'SELF' : 'FOREMAN',
          status: 'PENDING',
          flags: const Value('[]'),
        ),
      );
      await _outbox.enqueue(
        type: SyncOp.timeEntryClockIn,
        targetId: id,
        payload: {
          'id': id,
          'projectId': projectId,
          if (membershipId != recordedByMembershipId)
            'membershipId': membershipId,
          'deviceRecordedAt': cuando.toUtc().toIso8601String(),
          ..._evidencia(evidence),
        },
        occurredAt: cuando,
      );
    });

    return id;
  }

  /// Marca la salida de una jornada abierta.
  Future<void> clockOut(
    String entryId, {
    ClockEvidence evidence = const ClockEvidence(),
    int breakMinutes = 0,
    DateTime? occurredAt,
  }) async {
    final cuando = occurredAt ?? DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.timeEntries)..where((t) => t.id.equals(entryId)))
          .write(
        TimeEntriesCompanion(
          updatedAt: Value(cuando),
          syncStatus: const Value(SyncStatus.pending),
          clockOutAt: Value(cuando),
          breakMinutes: Value(breakMinutes),
        ),
      );
      await _outbox.enqueue(
        type: SyncOp.timeEntryClockOut,
        targetId: entryId,
        payload: {
          'deviceRecordedAt': cuando.toUtc().toIso8601String(),
          if (breakMinutes > 0) 'breakMinutes': breakMinutes,
          ..._evidencia(evidence),
        },
        occurredAt: cuando,
      );
    });
  }

  // ─── Mapeo ─────────────────────────────────────────────────────────────────

  /// Solo lo que hay. `withinGeofence` y `distanceM` no existen acá: los deriva
  /// el servidor y mandarlos volvería decorativo el control (ADR-0003).
  Map<String, Object?> _evidencia(ClockEvidence e) => {
    if (e.lat != null) 'lat': e.lat,
    if (e.lng != null) 'lng': e.lng,
    if (e.accuracyM != null) 'accuracyM': e.accuracyM,
    if (e.photoId != null) 'photoId': e.photoId,
    if (e.isMockLocation) 'isMockLocation': true,
    'recordedOffline': e.recordedOffline,
  };

  static TimeEntrySummary _resumen(LocalTimeEntry fila) => TimeEntrySummary(
    id: fila.id,
    projectId: fila.projectId,
    membershipId: fila.membershipId,
    recordedByMembershipId: fila.recordedByMembershipId,
    clockInAt: fila.clockInAt,
    clockOutAt: fila.clockOutAt,
    breakMinutes: fila.breakMinutes,
    method: fila.method,
    status: fila.status,
    flags: (jsonDecode(fila.flags) as List<dynamic>).cast<String>(),
    syncStatus: fila.syncStatus,
  );
}

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  return TimeEntryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxProvider),
    ref.watch(uuidProvider),
  );
});
