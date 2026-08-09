import '../../api/models/project_status.dart';

/// Obras sintéticas. **No son dominio**: existen para que la estructura sea
/// navegable y verificable antes de que la lista real tenga sus datos. Este
/// archivo se borra entero cuando llegue la capa local.
///
/// Los textos de acá **no** pasan por i18n a propósito: son datos —nombres de
/// obra, clientes y direcciones—, no interfaz. Un nombre de obra no se traduce.
class SampleProject {
  const SampleProject({
    required this.id,
    required this.name,
    required this.customer,
    required this.site,
    required this.status,
    required this.photoCount,
    this.crew,
  });

  final String id;
  final String name;
  final String customer;
  final String site;
  final ProjectStatus status;
  final int photoCount;

  /// Quién está asignado hoy. `null` en las obras que todavía no arrancaron.
  final String? crew;

  String get location => '/projects/$id';

  /// Una obra viva: ni terminada ni cancelada. Es lo que el dueño necesita ver
  /// al abrir la app — lo cerrado se consulta, no se vigila.
  bool get isActive =>
      status != ProjectStatus.completed && status != ProjectStatus.cancelled;
}

const sampleProjects = <SampleProject>[
  SampleProject(
    id: 'a1',
    name: 'Kitchen remodel',
    customer: 'Martínez family',
    site: '412 Ellsworth Dr, Silver Spring',
    status: ProjectStatus.inProgress,
    photoCount: 34,
    crew: 'Crew A',
  ),
  SampleProject(
    id: 'a2',
    name: 'Roof replacement',
    customer: 'Sandra Whitfield',
    site: '89 Bel Pre Rd, Rockville',
    status: ProjectStatus.inProgress,
    photoCount: 18,
    crew: 'Crew B',
  ),
  SampleProject(
    id: 'a3',
    name: 'Deck rebuild',
    customer: 'Thompson & Sons',
    site: '1720 Colesville Rd, Wheaton',
    status: ProjectStatus.onHold,
    photoCount: 7,
    crew: 'Crew A',
  ),
  SampleProject(
    id: 'a4',
    name: 'Bathroom addition',
    customer: 'Patel residence',
    site: '55 Georgia Ave, Aspen Hill',
    status: ProjectStatus.scheduled,
    photoCount: 0,
  ),
  SampleProject(
    id: 'a5',
    name: 'Siding replacement',
    customer: 'Greenfield HOA',
    site: '300 Norbeck Rd, Olney',
    status: ProjectStatus.estimated,
    photoCount: 0,
  ),
  SampleProject(
    id: 'a6',
    name: 'Garage conversion',
    customer: "O'Brien household",
    site: '77 Randolph Rd, Glenmont',
    status: ProjectStatus.lead,
    photoCount: 0,
  ),
  SampleProject(
    id: 'a7',
    name: 'Front porch repair',
    customer: 'Alicia Romero',
    site: '210 Fenton St, Silver Spring',
    status: ProjectStatus.completed,
    photoCount: 52,
  ),
  SampleProject(
    id: 'a8',
    name: 'Basement finishing',
    customer: 'Nguyen family',
    site: '904 Veirs Mill Rd, Rockville',
    status: ProjectStatus.completed,
    photoCount: 41,
  ),
  SampleProject(
    id: 'a9',
    name: 'Window replacement',
    customer: 'Dupont rental',
    site: '18 Piney Branch Rd, Takoma Park',
    status: ProjectStatus.cancelled,
    photoCount: 3,
  ),
];

List<SampleProject> get activeSampleProjects =>
    sampleProjects.where((proyecto) => proyecto.isActive).toList();

SampleProject? sampleProjectById(String id) {
  for (final proyecto in sampleProjects) {
    if (proyecto.id == id) return proyecto;
  }
  return null;
}
