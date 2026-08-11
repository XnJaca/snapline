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
    OutboxOperations,
    SyncCursors,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'snapline'));

  @override
  int get schemaVersion => 3;

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
    },
  );

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
