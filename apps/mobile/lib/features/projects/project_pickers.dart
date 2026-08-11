import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../customers/customer_form_sheet.dart';
import '../customers/site_form_sheet.dart';

/// Elegir el cliente de una obra, con la salida de crearlo en el acto.
///
/// **El "＋ nuevo" abre el formulario de SPEC-0006, no una copia.** William está
/// parado en la obra con el cliente al lado, y ese es el único momento en que tiene
/// los datos: mandarlo a otra pantalla es cuando la gente deja de cargar y vuelve
/// al cuaderno.
Future<String?> showCustomerPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _CustomerPicker(),
  );
}

/// Elegir la propiedad, entre las **de ese cliente**.
///
/// El `customerId` no es opcional a propósito: el `site_id` tiene que pertenecer al
/// `customer_id` y no se cruzan, así que no existe elegir propiedad sin cliente.
Future<String?> showSitePicker(
  BuildContext context, {
  required String customerId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SitePicker(customerId: customerId),
  );
}

class _CustomerPicker extends ConsumerWidget {
  const _CustomerPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clientes = ref.watch(customersProvider('')).value ?? const [];

    return _PickerSheet(
      title: l10n.projectPickCustomerTitle,
      newLabel: l10n.projectPickCustomerNew,
      onNew: () async {
        final id = await showCustomerFormSheet(context);
        if (id != null && context.mounted) Navigator.of(context).pop(id);
      },
      items: [
        for (final cliente in clientes)
          _PickerItem(
            title: cliente.displayName,
            subtitle: cliente.companyName ?? cliente.phone,
            pending: cliente.pending,
            onTap: () => Navigator.of(context).pop(cliente.id),
          ),
      ],
    );
  }
}

class _SitePicker extends ConsumerWidget {
  const _SitePicker({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sitios = ref.watch(customerSitesProvider(customerId)).value ?? const [];

    return _PickerSheet(
      title: l10n.projectPickSiteTitle,
      newLabel: l10n.projectPickSiteNew,
      onNew: () async {
        final id = await showSiteFormSheet(context, customerId: customerId);
        if (id != null && context.mounted) Navigator.of(context).pop(id);
      },
      items: [
        for (final sitio in sitios)
          _PickerItem(
            title: sitio.oneLine,
            pending: sitio.pending,
            onTap: () => Navigator.of(context).pop(sitio.id),
          ),
      ],
    );
  }
}

/// La forma de una hoja para elegir: el "＋ nuevo" arriba y la lista abajo.
///
/// Arriba y no al final: al final de algo scrolleable solo lo encuentra quien ya
/// sabía que estaba, y crear en el acto es la mitad del punto de esta pantalla.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.newLabel,
    required this.onNew,
    required this.items,
  });

  final String title;
  final String newLabel;
  final VoidCallback onNew;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
            child: Row(
              children: [
                Expanded(child: Text(title, style: context.texts.titleLarge)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(newLabel),
                  onPressed: onNew,
                ),
              ],
            ),
          ),
          Divider(height: 0, color: colors.outline),
          Flexible(
            child: items.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(spacing.xl),
                    child: Text(
                      l10n.projectPickEmpty,
                      style: context.texts.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(shrinkWrap: true, children: items),
          ),
          SizedBox(height: spacing.md),
        ],
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  const _PickerItem({
    required this.title,
    required this.onTap,
    required this.pending,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      title: Text(title),
      subtitle: subtitle?.isNotEmpty == true ? Text(subtitle!) : null,
      // Lo que se creó en este teléfono y todavía no subió se puede elegir igual:
      // su id ya es el definitivo.
      trailing: pending
          ? Icon(
              Icons.cloud_upload_outlined,
              size: context.spacing.lg,
              color: context.colors.onSurfaceVariant,
              semanticLabel: l10n.projectPendingSync,
            )
          : null,
      onTap: onTap,
    );
  }
}
