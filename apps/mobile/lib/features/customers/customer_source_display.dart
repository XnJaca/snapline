import '../../api/models/customer_source.dart';
import '../../l10n/app_localizations.dart';

/// Cómo llegó el cliente, con la etiqueta que William reconoce. Alimenta el
/// reporte de de dónde viene el trabajo; acá es solo un selector.
extension CustomerSourceDisplay on CustomerSource {
  String label(AppLocalizations l10n) => switch (this) {
    CustomerSource.referral => l10n.customerSourceReferral,
    CustomerSource.web => l10n.customerSourceWeb,
    CustomerSource.social => l10n.customerSourceSocial,
    CustomerSource.repeat => l10n.customerSourceRepeat,
    CustomerSource.other => l10n.customerSourceOther,
    // Un valor que el servidor conoce y esta versión de la app no.
    CustomerSource.$unknown => l10n.customerSourceOther,
  };
}
