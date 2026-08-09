import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/theme_extensions.dart';
import 'status_chip.dart';

/// Andamiaje: lo que se ve en un destino que todavía no tiene su spec.
///
/// La lista sintética no es relleno — es lo que permite verificar que cambiar
/// de pestaña y volver conserva la posición de scroll. Se borra cuando la
/// pantalla real llegue.
class PlaceholderList extends StatelessWidget {
  const PlaceholderList({
    super.key,
    required this.storageKey,
    this.itemCount = 30,
  });

  /// Identifica la lista dentro del árbol para que el scroll sobreviva a que el
  /// widget se reconstruya al volver a la pestaña.
  final String storageKey;

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: StatusChip(
            tone: StatusTone.info,
            label: l10n.comingSoon,
            expand: true,
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: PageStorageKey<String>(storageKey),
            padding: EdgeInsets.only(bottom: spacing.xxl),
            itemCount: itemCount,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: context.colors.outline),
            itemBuilder: (context, index) => ListTile(
              minTileHeight: spacing.touchTargetPrimary,
              leading: Icon(
                Icons.circle_outlined,
                color: context.colors.onSurfaceVariant,
              ),
              title: Text(l10n.placeholderItem(index + 1)),
            ),
          ),
        ),
      ],
    );
  }
}
