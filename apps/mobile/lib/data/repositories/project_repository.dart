import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/project_status.dart';
import '../local/app_database.dart';
import '../local/tables.dart';

/// Una obra con lo que la pantalla necesita mostrar, ya resuelto.
///
/// El cliente y la dirección viven en otras tablas; juntarlos acá evita que cada
/// widget arme su propia consulta y que la lista dispare una por card.
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.customerName,
    required this.site,
    required this.status,
    required this.pending,
  });

  final String id;
  final String name;
  final String? description;
  final String customerName;
  final String site;
  final ProjectStatus status;

  /// Todavía no llegó al servidor. La pantalla lo muestra: guardar y que se vea
  /// como si estuviera sincronizado es lo que después nadie entiende.
  final bool pending;
}

/// La puerta de las pantallas a las obras.
///
/// **Devuelve streams de la base local, nunca de la red.** El sincronizador
/// escribe en Drift y la pantalla se entera sola; sin señal no hay una ruta
/// distinta que recorrer.
class ProjectRepository {
  const ProjectRepository(this._db);

  final AppDatabase _db;

  /// Lo que está en obra ahora.
  Stream<List<ProjectSummary>> watchInProgress() =>
      _watch(status: ProjectStatus.inProgress);

  /// Toda la cartera, o un estado si se pide.
  Stream<List<ProjectSummary>> watchAll({ProjectStatus? status}) =>
      _watch(status: status);

  Stream<List<ProjectSummary>> _watch({ProjectStatus? status}) {
    final consulta = _db.select(_db.projects).join([
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.projects.customerId),
      ),
      leftOuterJoin(_db.sites, _db.sites.id.equalsExp(_db.projects.siteId)),
    ]);

    // Borrado suave: la fila sigue en la base para poder propagarse, pero no se
    // lista (regla 20).
    consulta.where(_db.projects.deletedAt.isNull());
    if (status != null) {
      consulta.where(_db.projects.status.equals(status.json!));
    }
    consulta.orderBy([OrderingTerm.desc(_db.projects.updatedAt)]);

    return consulta.watch().map(
      (filas) => filas.map((fila) {
        final proyecto = fila.readTable(_db.projects);
        final cliente = fila.readTableOrNull(_db.customers);
        final sitio = fila.readTableOrNull(_db.sites);

        return ProjectSummary(
          id: proyecto.id,
          name: proyecto.name,
          description: proyecto.description,
          customerName: cliente?.displayName ?? '',
          site: _direccion(sitio?.address),
          status: ProjectStatus.fromJson(proyecto.status),
          pending: proyecto.syncStatus != SyncStatus.synced,
        );
      }).toList(),
    );
  }

  Stream<ProjectSummary?> watchOne(String id) =>
      _watch().map((todos) => todos.where((p) => p.id == id).firstOrNull);

  /// La dirección se guarda como el JSON que mandó el servidor. Una línea sola
  /// alcanza para la card; el detalle completo lo arma quien lo necesite.
  static String _direccion(String? json) {
    if (json == null) return '';
    try {
      final mapa = jsonDecode(json) as Map<String, Object?>;
      final partes = [mapa['line1'], mapa['city'], mapa['state']]
          .whereType<String>()
          .where((p) => p.isNotEmpty);
      return partes.join(', ');
    } catch (_) {
      return '';
    }
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(appDatabaseProvider));
});

final inProgressProjectsProvider = StreamProvider<List<ProjectSummary>>((ref) {
  return ref.watch(projectRepositoryProvider).watchInProgress();
});

final projectByIdProvider = StreamProvider.family<ProjectSummary?, String>((
  ref,
  id,
) {
  return ref.watch(projectRepositoryProvider).watchOne(id);
});

final allProjectsProvider =
    StreamProvider.family<List<ProjectSummary>, ProjectStatus?>((ref, status) {
      return ref.watch(projectRepositoryProvider).watchAll(status: status);
    });
