import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/project_status.dart';
import '../local/address_json.dart';
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

  /// Las obras de un cliente, en cualquier estado: la ficha del cliente las
  /// muestra todas, incluidas las cerradas.
  Stream<List<ProjectSummary>> watchByCustomer(String customerId) =>
      _watch(customerId: customerId);

  Stream<List<ProjectSummary>> _watch({
    ProjectStatus? status,
    String? customerId,
  }) {
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
    if (customerId != null) {
      consulta.where(_db.projects.customerId.equals(customerId));
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
          site: AddressJson.oneLine(AddressJson.decode(sitio?.address)),
          status: ProjectStatus.fromJson(proyecto.status),
          pending: proyecto.syncStatus != SyncStatus.synced,
        );
      }).toList(),
    );
  }

  Stream<ProjectSummary?> watchOne(String id) =>
      _watch().map((todos) => todos.where((p) => p.id == id).firstOrNull);
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

/// Las obras de un cliente. Las usa su ficha.
final projectsByCustomerProvider =
    StreamProvider.family<List<ProjectSummary>, String>((ref, customerId) {
      return ref.watch(projectRepositoryProvider).watchByCustomer(customerId);
    });
