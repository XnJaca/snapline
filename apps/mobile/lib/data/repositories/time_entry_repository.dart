import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/address_json.dart';
import '../local/app_database.dart';
import '../local/tables.dart';
import '../sync/outbox.dart';

/// Una obra con asignación para hoy, como la ofrece la pantalla Hoy.
extension TimeEntryWorked on TimeEntrySummary {
  /// Lo trabajado en la jornada. La abierta corre hasta ahora — y se calcula
  /// en un solo lugar, para que ninguna pantalla la cuente distinto.
  Duration get worked =>
      (clockOutAt ?? DateTime.now()).difference(clockInAt) -
      Duration(minutes: breakMinutes);
}

typedef ObraDetalle = ({
  String status,
  String? serviceType,
  String? description,
  DateTime? startDate,
  DateTime? targetEndDate,
  DateTime? actualEndDate,
});

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
    this.decisionReason,
    this.recordedOffline = false,
    this.lastRejection,
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

  /// Por qué se aprobó o se rechazó.
  final String? decisionReason;

  final bool recordedOffline;

  /// El código del último rechazo del servidor sobre una decisión de esta
  /// jornada. La pantalla lo traduce; acá viaja crudo (regla 24).
  final String? lastRejection;

  bool get abierta => clockOutAt == null;
  bool get enConflicto => syncStatus == SyncStatus.conflict;
  bool get pendiente => syncStatus != SyncStatus.synced;

  bool get aprobada => status == 'APPROVED';
  bool get rechazada => status == 'REJECTED';
  bool get sinAprobar => status == 'PENDING';
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

  /// Todas las jornadas de una obra, de cualquier persona: el tab Horas.
  ///
  /// **Sin ventana de tiempo, a diferencia de las vistas de campo.** Acá la
  /// pregunta es cuántas horas lleva la obra, y ese número es su vida entera
  /// (SPEC-0011).
  ///
  /// El nombre sale de `people`, que baja con el pull. Un `LEFT JOIN` porque la
  /// jornada tiene que aparecer igual si la persona todavía no bajó: esconder
  /// horas por un nombre faltante sería peor que mostrarlas sin él.
  Stream<List<({String name, String recordedByName, TimeEntrySummary entry})>>
      watchProjectEntries(String projectId) {
    // Dos alias de la misma tabla: de quién son las horas, y quién las marcó.
    final duena = _db.alias(_db.people, 'pe');
    final marcador = _db.alias(_db.people, 'rec');

    final query = _db.select(_db.timeEntries)
      ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.clockInAt)]);

    // `leftOuterJoin` y no `innerJoin`: la jornada tiene que aparecer aunque la
    // persona todavía no haya bajado. Esconder horas por un nombre faltante
    // sería peor que mostrarlas sin él.
    return query
        .join([
          leftOuterJoin(
            duena,
            duena.membershipId.equalsExp(_db.timeEntries.membershipId),
          ),
          leftOuterJoin(
            marcador,
            marcador.membershipId
                .equalsExp(_db.timeEntries.recordedByMembershipId),
          ),
        ])
        .watch()
        .map(
          (filas) => filas
              .map(
                (f) => (
                  name: f.readTableOrNull(duena)?.name ?? '',
                  recordedByName: f.readTableOrNull(marcador)?.name ?? '',
                  entry: _resumen(f.readTable(_db.timeEntries)),
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
  /// Las obras donde **esta cuadrilla** trabaja hoy: las asignadas a la
  /// cuadrilla y las que tenga asignada su gente a título propio.
  ///
  /// Es lo que acota el tab Personas cuando se entra por una cuadrilla y no
  /// por el eje: sin esto, la pantalla de la Cuadrilla B mostraría la gente de
  /// la obra de la A.
  Stream<List<TodayProject>> watchTodayProjectsForCrew(String crewId) {
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
      LEFT JOIN crew_members cm ON cm.crew_id = ?1
        AND cm.deleted_at IS NULL
        AND a.work_date >= cm.from_date
        AND (cm.to_date IS NULL OR a.work_date <= cm.to_date)
      WHERE a.deleted_at IS NULL
        AND a.work_date >= ?2 AND a.work_date < ?3
        AND (a.crew_id = ?1 OR a.membership_id = cm.membership_id)
      ORDER BY p.name
      ''',
      variables: [
        Variable<String>(crewId),
        Variable<DateTime>(inicio),
        Variable<DateTime>(fin),
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

  /// La ficha de la obra para el tab Detalle: estado, fechas y descripción —
  /// solo lo que ya baja al teléfono. Fases no: no existen en el dominio.
  Stream<ObraDetalle?> watchObraDetalle(String projectId) {
    final consulta = _db.select(_db.projects)
      ..where((p) => p.id.equals(projectId) & p.deletedAt.isNull());
    return consulta.watchSingleOrNull().map(
      (p) => p == null
          ? null
          : (
              status: p.status,
              serviceType: p.serviceType,
              description: p.description,
              startDate: p.startDate,
              targetEndDate: p.targetEndDate,
              actualEndDate: p.actualEndDate,
            ),
    );
  }

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

  /// Aprueba o rechaza una jornada. Escribe en local y encola, como todo lo
  /// demás: sin señal la pantalla responde igual (SPEC-0011).
  ///
  /// `decidedFrom` guarda el estado que la jornada tenía al decidir. Viaja como
  /// `expectedStatus` —el servidor lo compara antes de aplicar— y es de dónde se
  /// restituye `status` si la decisión termina rechazada. Sin él, aprobar sobre
  /// algo que otro ya rechazó se aplicaría en silencio (regla 12).
  Future<void> decide(
    String entryId, {
    required bool approve,
    String? reason,
    DateTime? occurredAt,
  }) async {
    final cuando = occurredAt ?? DateTime.now();

    // **Toda la decisión toma el turno de la bandeja**, incluida la escritura
    // local. Es la excepción a que la pantalla nunca espera: `decidedFrom` sale
    // de `status`, y `status` solo dice lo que el servidor tiene hasta que un
    // push en vuelo lo confirma. Leerlo en el medio de ese push deja la decisión
    // pidiendo un estado viejo, y el servidor la rechaza por chocar con la
    // anterior — quedando aplicada la que la persona descartó.
    //
    // Lo que se espera es un push, no una red: sin señal falla enseguida y el
    // turno se libera. Y esto es aprobar, que es de oficina — el marcaje que la
    // regla 9 protege no pasa por acá.
    await _outbox.exclusivo(() => _db.transaction(() async {
      final fila = await (_db.select(_db.timeEntries)
            ..where((t) => t.id.equals(entryId)))
          .getSingleOrNull();
      if (fila == null) return;

      // **Una sola decisión pendiente por jornada.** Cambiar de opinión antes de
      // que la primera salga sustituye la intención, no agrega otra: encoladas
      // las dos, el servidor aplicaría la primera y rechazaría la segunda por no
      // coincidir con el estado que ya cambió — y la jornada quedaría con la
      // decisión que la persona descartó.
      await _outbox.replacePending(entryId, _decisiones);

      // Lo que la jornada era antes de la **primera** decisión sin sincronizar.
      // Es lo que el servidor todavía tiene, así que es contra lo que compara; y
      // es a donde se vuelve si la rechaza.
      final desde = fila.decidedFrom ?? fila.status;

      await (_db.update(_db.timeEntries)..where((t) => t.id.equals(entryId)))
          .write(
        TimeEntriesCompanion(
          updatedAt: Value(cuando),
          syncStatus: const Value(SyncStatus.pending),
          status: Value(approve ? 'APPROVED' : 'REJECTED'),
          decisionReason: Value(reason),
          decidedFrom: Value(desde),
          lastRejection: const Value(null),
        ),
      );
      await _outbox.enqueue(
        type: approve ? SyncOp.timeEntryApprove : SyncOp.timeEntryReject,
        targetId: entryId,
        payload: {
          'expectedStatus': desde,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
        occurredAt: cuando,
      );
    }));
  }

  static const _decisiones = {
    SyncOp.timeEntryApprove,
    SyncOp.timeEntryReject,
  };

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
    decisionReason: fila.decisionReason,
    recordedOffline: fila.recordedOffline,
    lastRejection: fila.lastRejection,
  );
}

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  return TimeEntryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxProvider),
    ref.watch(uuidProvider),
  );
});
