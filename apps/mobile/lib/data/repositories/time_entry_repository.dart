import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/address_json.dart';
import '../local/app_database.dart';
import '../local/tables.dart';
import '../sync/outbox.dart';

/// Una obra con asignación para hoy, como la ofrece la pantalla Hoy.
class TodayProject {
  const TodayProject({
    required this.id,
    required this.name,
    required this.siteId,
    required this.address,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String siteId;

  /// La dirección en una línea, para saber a dónde ir. Vacía si la propiedad
  /// no está en local todavía.
  final String address;

  /// El punto de SPEC-0007, si alguien lo fijó: abre Mapas en el lugar exacto
  /// y no en el centro de la manzana.
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;
}

/// Una persona de la obra de hoy, con el estado de su jornada.
class CrewmateToday {
  const CrewmateToday({
    required this.membershipId,
    required this.name,
    required this.role,
    this.openEntryId,
    this.lastClockIn,
    this.lastClockOut,
  });

  final String membershipId;
  final String name;
  final String role;

  /// La jornada abierta de hoy en esta obra, si hay.
  final String? openEntryId;
  final DateTime? lastClockIn;
  final DateTime? lastClockOut;

  bool get adentro => openEntryId != null;
  bool get marcoHoy => lastClockIn != null;
}

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

  /// Las jornadas de una persona en una obra puntual: el tab Registro.
  Stream<List<TimeEntrySummary>> watchForProject(
    String membershipId,
    String projectId,
    DateTime desde,
  ) {
    return (_db.select(_db.timeEntries)
          ..where(
            (t) =>
                t.membershipId.equals(membershipId) &
                t.projectId.equals(projectId) &
                t.clockInAt.isBiggerOrEqualValue(desde) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.clockInAt)]))
        .watch()
        .map((filas) => filas.map(_resumen).toList(growable: false));
  }

  /// Las cuadrillas que la persona lidera o integra hoy: la lista del eje.
  Stream<List<({String id, String name})>> watchMyCrews(String membershipId) {
    final consulta = _db.customSelect(
      '''
      SELECT DISTINCT c.id AS id, c.name AS name
      FROM crews c
      LEFT JOIN crew_members cm ON cm.crew_id = c.id AND cm.deleted_at IS NULL
      WHERE c.deleted_at IS NULL
        AND (c.foreman_membership_id = ?1
             OR (cm.membership_id = ?1
                 AND cm.from_date <= ?2
                 AND (cm.to_date IS NULL OR cm.to_date >= ?2)))
      ORDER BY c.name
      ''',
      variables: [
        Variable<String>(membershipId),
        Variable<DateTime>(DateTime.now()),
      ],
      readsFrom: {_db.crews, _db.crewMembers},
    );
    return consulta.watch().map(
      (filas) => filas
          .map((f) => (id: f.read<String>('id'), name: f.read<String>('name')))
          .toList(growable: false),
    );
  }

  /// Las jornadas de la semana de toda la gente de una cuadrilla, para que el
  /// tab Horas las sume. Vienen crudas y se agregan en Dart: la jornada
  /// abierta cuenta con el reloj corriendo, y eso no se congela en SQL.
  Stream<List<({String membershipId, String name, TimeEntrySummary? entry})>>
      watchCrewWeekEntries(String crewId, DateTime desde) {
    final consulta = _db.customSelect(
      '''
      SELECT pe.membership_id AS membership_id, pe.name AS name,
             t.id AS entry_id, t.project_id AS project_id,
             t.recorded_by_membership_id AS recorded_by,
             t.clock_in_at AS clock_in_at, t.clock_out_at AS clock_out_at,
             t.break_minutes AS break_minutes, t.method AS method,
             t.status AS status, t.flags AS flags, t.sync_status AS sync_status
      FROM crew_members cm
      JOIN people pe ON pe.membership_id = cm.membership_id
      LEFT JOIN time_entries t ON t.membership_id = cm.membership_id
        AND t.deleted_at IS NULL AND t.clock_in_at >= ?2
      WHERE cm.crew_id = ?1 AND cm.deleted_at IS NULL
      ORDER BY pe.name ASC, t.clock_in_at DESC
      ''',
      variables: [Variable<String>(crewId), Variable<DateTime>(desde)],
      readsFrom: {_db.crewMembers, _db.people, _db.timeEntries},
    );
    return consulta.watch().map(
      (filas) => filas
          .map(
            (f) => (
              membershipId: f.read<String>('membership_id'),
              name: f.read<String>('name'),
              entry: f.readNullable<String>('entry_id') == null
                  ? null
                  : TimeEntrySummary(
                      id: f.read<String>('entry_id'),
                      projectId: f.read<String>('project_id'),
                      membershipId: f.read<String>('membership_id'),
                      recordedByMembershipId: f.read<String>('recorded_by'),
                      clockInAt: f.read<DateTime>('clock_in_at'),
                      clockOutAt: f.readNullable<DateTime>('clock_out_at'),
                      breakMinutes: f.read<int>('break_minutes'),
                      method: f.read<String>('method'),
                      status: f.read<String>('status'),
                      flags: (jsonDecode(f.read<String>('flags'))
                              as List<dynamic>)
                          .cast<String>(),
                      syncStatus: SyncStatus
                          .values[f.read<int>('sync_status')],
                    ),
            ),
          )
          .toList(growable: false),
    );
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

  /// Las obras donde la persona tiene asignación **hoy**, directa o por una
  /// cuadrilla que integra hoy.
  ///
  /// Solo asignadas: la cuadrilla no navega la cartera (SPEC-0003), así que la
  /// obra del día llega por `project_assignment` o no llega. El estado vacío lo
  /// explica la pantalla.
  Stream<List<TodayProject>> watchTodayProjects(String membershipId) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));

    final consulta = _db.customSelect(
      '''
      SELECT DISTINCT p.id AS id, p.name AS name, p.site_id AS site_id,
             s.address AS address, s.lat AS lat, s.lng AS lng
      FROM project_assignments a
      JOIN projects p ON p.id = a.project_id AND p.deleted_at IS NULL
      LEFT JOIN sites s ON s.id = p.site_id AND s.deleted_at IS NULL
      LEFT JOIN crew_members cm ON cm.crew_id = a.crew_id
        AND cm.deleted_at IS NULL
        AND a.work_date >= cm.from_date
        AND (cm.to_date IS NULL OR a.work_date <= cm.to_date)
      WHERE a.deleted_at IS NULL
        AND a.work_date >= ? AND a.work_date < ?
        AND (a.membership_id = ? OR cm.membership_id = ?)
      ORDER BY p.name
      ''',
      variables: [
        Variable<DateTime>(inicio),
        Variable<DateTime>(fin),
        Variable<String>(membershipId),
        Variable<String>(membershipId),
      ],
      readsFrom: {
        _db.projectAssignments,
        _db.projects,
        _db.sites,
        _db.crewMembers,
      },
    );

    return consulta.watch().map(
      (filas) => filas.map(_obraDeHoy).toList(growable: false),
    );
  }

  /// El lugar de una obra puntual: el contexto de la jornada abierta, que no
  /// depende de que la asignación de hoy siga existiendo.
  Stream<TodayProject?> watchPlace(String projectId) {
    final consulta = _db.customSelect(
      '''
      SELECT p.id AS id, p.name AS name, p.site_id AS site_id,
             s.address AS address, s.lat AS lat, s.lng AS lng
      FROM projects p
      LEFT JOIN sites s ON s.id = p.site_id AND s.deleted_at IS NULL
      WHERE p.id = ? AND p.deleted_at IS NULL
      ''',
      variables: [Variable<String>(projectId)],
      readsFrom: {_db.projects, _db.sites},
    );
    return consulta
        .watch()
        .map((filas) => filas.isEmpty ? null : _obraDeHoy(filas.first));
  }

  static TodayProject _obraDeHoy(QueryRow f) => TodayProject(
    id: f.read<String>('id'),
    name: f.read<String>('name'),
    siteId: f.read<String>('site_id'),
    address: AddressJson.oneLine(
      AddressJson.decode(f.readNullable<String>('address')),
    ),
    lat: f.readNullable<double>('lat'),
    lng: f.readNullable<double>('lng'),
  );

  /// La gente asignada a una obra **hoy** —directa o por cuadrilla— con el
  /// estado de su jornada: es la lista del foreman, quién marcó y quién no.
  Stream<List<CrewmateToday>> watchCrewToday(String projectId) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));

    final consulta = _db.customSelect(
      '''
      SELECT pe.membership_id AS membership_id, pe.name AS name, pe.role AS role,
             t.id AS entry_id, t.clock_in_at AS clock_in_at,
             t.clock_out_at AS clock_out_at
      FROM (
        SELECT DISTINCT COALESCE(a.membership_id, cm.membership_id) AS membership_id
        FROM project_assignments a
        LEFT JOIN crew_members cm ON cm.crew_id = a.crew_id
          AND cm.deleted_at IS NULL
          AND a.work_date >= cm.from_date
          AND (cm.to_date IS NULL OR a.work_date <= cm.to_date)
        WHERE a.project_id = ?1 AND a.deleted_at IS NULL
          AND a.work_date >= ?2 AND a.work_date < ?3
      ) asignados
      JOIN people pe ON pe.membership_id = asignados.membership_id
      LEFT JOIN time_entries t ON t.membership_id = pe.membership_id
        AND t.project_id = ?1 AND t.deleted_at IS NULL
        AND t.clock_in_at >= ?2 AND t.clock_in_at < ?3
      ORDER BY pe.name ASC, t.clock_in_at DESC
      ''',
      variables: [
        Variable<String>(projectId),
        Variable<DateTime>(inicio),
        Variable<DateTime>(fin),
      ],
      readsFrom: {
        _db.projectAssignments,
        _db.crewMembers,
        _db.people,
        _db.timeEntries,
      },
    );

    return consulta.watch().map((filas) {
      // Varias jornadas de la misma persona en el día: gana la más reciente,
      // que es la primera por el ORDER BY.
      final porPersona = <String, CrewmateToday>{};
      for (final f in filas) {
        final id = f.read<String>('membership_id');
        if (porPersona.containsKey(id)) continue;
        final salida = f.readNullable<DateTime>('clock_out_at');
        final entrada = f.readNullable<DateTime>('clock_in_at');
        porPersona[id] = CrewmateToday(
          membershipId: id,
          name: f.read<String>('name'),
          role: f.read<String>('role'),
          openEntryId:
              entrada != null && salida == null ? f.readNullable<String>('entry_id') : null,
          lastClockIn: entrada,
          lastClockOut: salida,
        );
      }
      return porPersona.values.toList(growable: false);
    });
  }

  /// Toda la gente conocida en este teléfono. Es la salida de escape del
  /// foreman: marcar por alguien que no aparece asignado — la bandera del
  /// servidor lo señala, no lo bloquea.
  Stream<List<CrewmateToday>> watchEveryone() {
    return (_db.select(_db.people)
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch()
        .map(
          (filas) => filas
              .map(
                (p) => CrewmateToday(
                  membershipId: p.membershipId,
                  name: p.name,
                  role: p.role,
                ),
              )
              .toList(growable: false),
        );
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
    String recordedByRole = 'WORKER',
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
          // El mismo criterio que el servidor: SELF si es propio; si no, el
          // rol de quien marca. "Lo marcó un foreman" cuando marcó el dueño es
          // un dato falso en el rastro de la regla 12.
          method: membershipId == recordedByMembershipId
              ? 'SELF'
              : (recordedByRole == 'FOREMAN' ? 'FOREMAN' : 'ADMIN'),
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
