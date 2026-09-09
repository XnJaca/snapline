import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// La base local. **Es la única fuente de las pantallas**: la UI observa esto y
/// nunca la red, así que sin señal no hay una ruta distinta que recorrer.
///
/// Guarda lo de **una** empresa a la vez. El `companyId` viaja en cada fila para
/// poder detectar que la sesión cambió de empresa y limpiar, no para consultar
/// por él: el servidor ya filtra por tenant y el teléfono no ve más de una.
@DriftDatabase(
  tables: [
    Customers,
    Sites,
    Projects,
    ProjectAssignments,
    TimeEntries,
    Crews,
    CrewMembers,
    People,
    MediaAssets,
    ProjectStatusChanges,
    ProjectUpdates,
    PendingUploads,
    OutboxOperations,
    SyncCursors,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'snapline'));

  @override
  int get schemaVersion => 10;

  /// Se agregan columnas, no se recrea la base: un teléfono que actualiza la app
  /// con la jornada sin sincronizar no puede perder la bandeja de salida.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(customers, customers.firstName);
        await m.addColumn(customers, customers.lastName);
        await m.addColumn(customers, customers.source);
        await m.addColumn(customers, customers.notes);
      }
      if (from < 3) {
        // Tablas nuevas, nunca recrear: la bandeja con la jornada sin
        // sincronizar tiene que sobrevivir a la actualización.
        await m.createTable(timeEntries);
        await m.createTable(crews);
        await m.createTable(crewMembers);
        await m.createTable(people);
      }
      if (from < 4) {
        await m.createTable(pendingUploads);
      }
      if (from < 5) {
        // El photo release salió del producto (DEBT-0005). Es la primera columna
        // que se va: recrea `customers` y copia lo demás, sin tocar la bandeja.
        await m.alterTable(TableMigration(customers));
      }
      if (from < 6) {
        await m.createTable(mediaAssets);
        // `createTable` usa el esquema de HOY, no el de la versión que creó la
        // tabla: si el salto viene de antes de la v3, `time_entries` ya nació
        // con estas dos columnas y agregarlas otra vez falla por duplicado.
        if (from >= 3) {
          // Para excluir de la galería lo que es evidencia de asistencia.
          await m.addColumn(timeEntries, timeEntries.clockInPhotoId);
          await m.addColumn(timeEntries, timeEntries.clockOutPhotoId);
        }
        if (from >= 4) {
          await m.addColumn(pendingUploads, pendingUploads.bytes);
        }
      }
      if (from < 7) {
        // Aprobar y rechazar desde la obra (SPEC-0011). Mismo cuidado que en la
        // v6: si el salto viene de antes de la v3, `time_entries` se creó recién
        // con el esquema de hoy y ya las tiene.
        if (from >= 3) {
          await m.addColumn(timeEntries, timeEntries.decisionReason);
          await m.addColumn(timeEntries, timeEntries.recordedOffline);
          await m.addColumn(timeEntries, timeEntries.decidedFrom);
          await m.addColumn(timeEntries, timeEntries.lastRejection);
        }
      }
      if (from < 8) {
        // El hilo de Avance (SPEC-0012). Tablas nuevas, nada que migrar: las
        // dos las produce el servidor y bajan enteras en el próximo pull.
        await m.createTable(projectStatusChanges);
        await m.createTable(projectUpdates);
      }
      if (from < 9) {
        // El ancla del hilo. Queda nula hasta el próximo pull, y una obra sin
        // ancla simplemente no la muestra.
        await m.addColumn(projects, projects.createdAt);
      }
      if (from < 10) {
        // La asignación pasa de un día a un período (SPEC-0011): `work_date` se
        // convierte en `from_date` y aparece `to_date`, nula hasta que alguien
        // marque que la cuadrilla terminó ahí.
        //
        // **Se pregunta por la columna en vez de suponerla.** Es el mismo bicho
        // que la v6: `createTable` usa el esquema de HOY, así que una base cuya
        // tabla ya nació con `from_date` —pero con la versión guardada más
        // atrás— entra igual acá, y copiar desde `work_date` la revienta al
        // abrir. Pasó en un teléfono real: la app arrancaba y el sincronizador
        // fallaba en cada intento.
        if (await _tieneColumna('project_assignments', 'work_date')) {
          // El `columnTransformer` es lo que hace que el día viejo sobreviva
          // como fecha de entrada: sin él, drift copia por nombre, no encuentra
          // `from_date` en la tabla vieja y se lleva puesto lo que hubiera.
          await m.alterTable(TableMigration(
            projectAssignments,
            columnTransformer: {
              projectAssignments.fromDate:
                  const CustomExpression<DateTime>('work_date'),
            },
            newColumns: [projectAssignments.toDate],
          ));
        } else if (!await _tieneColumna('project_assignments', 'to_date')) {
          // La tabla ya está a medio camino: tiene `from_date` y le falta el
          // cierre. Se agrega y listo, sin recrear nada.
          await m.addColumn(projectAssignments, projectAssignments.toDate);
        }
      }
    },
  );

  /// Qué columnas tiene de verdad una tabla, para no migrar a ciegas.
  ///
  /// La versión guardada dice por dónde va la app, no cómo quedó el esquema: una
  /// tabla creada por `createTable` nace con la forma de hoy aunque el número
  /// diga otra cosa.
  Future<bool> _tieneColumna(String tabla, String columna) async {
    final filas = await customSelect(
      "SELECT name FROM pragma_table_info('$tabla')",
    ).get();
    return filas.any((f) => f.read<String>('name') == columna);
  }

  /// Todo lo local, sin excepción.
  ///
  /// Se llama al cerrar sesión y al detectar que la sesión entró con otra
  /// empresa: dejar datos de una empresa visibles bajo otra sesión sería el
  /// mismo problema que un `company_id` mal filtrado en el servidor, pero del
  /// lado del teléfono.
  Future<void> wipe() async {
    await transaction(() async {
      for (final tabla in allTables) {
        await delete(tabla).go();
      }
    });
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
