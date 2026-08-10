import '../../api/models/project_status.dart';

/// Las transiciones válidas de `docs/domain/proyecto.md`.
///
/// **Es una copia de `apps/api/src/projects/project-status.ts` y tiene que seguir
/// siéndolo.** No sale del contrato porque es lógica y no un DTO, así que la
/// paridad la verifica `test/project_transitions_test.dart`, que lee el archivo
/// del API y compara. Sin ese test, el selector ofrecería transiciones que el
/// servidor rechaza y el error aparecería recién al sincronizar.
const projectTransitions = <ProjectStatus, List<ProjectStatus>>{
  ProjectStatus.lead: [ProjectStatus.estimated, ProjectStatus.cancelled],
  ProjectStatus.estimated: [ProjectStatus.scheduled, ProjectStatus.cancelled],
  ProjectStatus.scheduled: [
    ProjectStatus.inProgress,
    ProjectStatus.onHold,
    ProjectStatus.cancelled,
  ],
  ProjectStatus.inProgress: [
    ProjectStatus.completed,
    ProjectStatus.onHold,
    ProjectStatus.cancelled,
  ],
  ProjectStatus.onHold: [ProjectStatus.inProgress, ProjectStatus.cancelled],
  ProjectStatus.completed: [],
  ProjectStatus.cancelled: [],
};

/// A qué estados puede pasar una obra que está en [actual].
///
/// Vacío significa terminal —terminada o cancelada— y la pantalla no ofrece
/// cambiar el estado en vez de mostrar un selector que no hace nada.
List<ProjectStatus> nextStatusesFor(ProjectStatus actual) =>
    projectTransitions[actual] ?? const [];
