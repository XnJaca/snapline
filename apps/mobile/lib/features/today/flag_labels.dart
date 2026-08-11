import '../../l10n/app_localizations.dart';

/// El texto de cada bandera del servidor.
///
/// Una bandera que esta versión de la app no conoce se muestra tal cual llega:
/// fea pero visible. Ocultarla sería esconderle al que aprueba justo lo que la
/// bandera existe para señalar.
String flagLabel(AppLocalizations l10n, String flag) => switch (flag) {
  'OUTSIDE_GEOFENCE' => l10n.flagOutsideGeofence,
  'NO_LOCATION' => l10n.flagNoLocation,
  'NO_PHOTO' => l10n.flagNoPhoto,
  'MOCK_LOCATION' => l10n.flagMockLocation,
  'SHIFT_TOO_LONG' => l10n.flagShiftTooLong,
  'TIMESTAMP_OUT_OF_RANGE' => l10n.flagTimestampOutOfRange,
  'RECORDER_NOT_ASSIGNED' => l10n.flagRecorderNotAssigned,
  'MISSING_CLOCK_OUT' => l10n.flagMissingClockOut,
  'MANUALLY_EDITED' => l10n.flagManuallyEdited,
  'OVERLAPPING_PROJECTS' => l10n.flagOverlappingProjects,
  _ => flag,
};
