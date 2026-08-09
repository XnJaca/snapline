import 'package:flutter/material.dart';

import '../../api/models/project_status.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';

/// El ciclo de vida de `docs/domain/proyecto.md`, en orden. El enum generado
/// sale en el orden del `openapi.json`, que no es el que espera quien filtra.
const projectStatusLifecycle = <ProjectStatus>[
  ProjectStatus.lead,
  ProjectStatus.estimated,
  ProjectStatus.scheduled,
  ProjectStatus.inProgress,
  ProjectStatus.onHold,
  ProjectStatus.completed,
  ProjectStatus.cancelled,
];

/// Cómo se muestra cada estado del dominio.
///
/// El tono responde a qué pide de quien mira, no a si el estado es "bueno":
/// verde es que la obra corre, ámbar que está trabada, rojo que murió y gris
/// que no pide nada. Los cuatro grises se distinguen por su icono, porque el
/// color solo nunca alcanza.
extension ProjectStatusDisplay on ProjectStatus {
  String label(AppLocalizations l10n) => switch (this) {
    ProjectStatus.lead => l10n.projectStatusLead,
    ProjectStatus.estimated => l10n.projectStatusEstimated,
    ProjectStatus.scheduled => l10n.projectStatusScheduled,
    ProjectStatus.inProgress => l10n.projectStatusInProgress,
    ProjectStatus.onHold => l10n.projectStatusOnHold,
    ProjectStatus.completed => l10n.projectStatusCompleted,
    ProjectStatus.cancelled => l10n.projectStatusCancelled,
    ProjectStatus.$unknown => l10n.projectUntitled,
  };

  StatusTone get tone => switch (this) {
    ProjectStatus.inProgress => StatusTone.success,
    ProjectStatus.onHold => StatusTone.warning,
    ProjectStatus.cancelled => StatusTone.danger,
    _ => StatusTone.info,
  };

  IconData get icon => switch (this) {
    ProjectStatus.lead => Icons.person_search_outlined,
    ProjectStatus.estimated => Icons.request_quote_outlined,
    ProjectStatus.scheduled => Icons.event_outlined,
    ProjectStatus.inProgress => Icons.construction,
    ProjectStatus.onHold => Icons.pause_circle_outline,
    ProjectStatus.completed => Icons.check_circle_outline,
    ProjectStatus.cancelled => Icons.cancel_outlined,
    ProjectStatus.$unknown => Icons.help_outline,
  };
}
