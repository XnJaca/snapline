import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';

/// Obras sintéticas. **No son dominio**: existen para que la estructura de
/// navegación sea navegable y verificable antes de que la lista real tenga su
/// spec. Este archivo se borra entero cuando eso pase.
enum SampleProjectStatus {
  inProgress,
  completed;

  String label(AppLocalizations l10n) => switch (this) {
    SampleProjectStatus.inProgress => l10n.projectStatusInProgress,
    SampleProjectStatus.completed => l10n.projectStatusCompleted,
  };

  StatusTone get tone => switch (this) {
    SampleProjectStatus.inProgress => StatusTone.info,
    SampleProjectStatus.completed => StatusTone.success,
  };
}

class SampleProject {
  const SampleProject({
    required this.id,
    required this.number,
    required this.status,
  });

  final String id;
  final int number;
  final SampleProjectStatus status;

  String name(AppLocalizations l10n) => l10n.placeholderProject(number);

  String get location => '/projects/$id';
}

/// Con uno terminado cada cuatro: hace falta al menos uno para verificar que un
/// proyecto cerrado muestra las mismas tabs que uno en curso.
final sampleProjects = List<SampleProject>.generate(12, (indice) {
  final numero = indice + 1;
  return SampleProject(
    id: 'sample-$numero',
    number: numero,
    status: numero % 4 == 0
        ? SampleProjectStatus.completed
        : SampleProjectStatus.inProgress,
  );
}, growable: false);

SampleProject? sampleProjectById(String id) {
  for (final proyecto in sampleProjects) {
    if (proyecto.id == id) return proyecto;
  }
  return null;
}
