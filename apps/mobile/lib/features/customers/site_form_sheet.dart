import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/app_localizations.dart';
import 'address_fields.dart';
import 'form_sheet.dart';
import 'site_location_block.dart';

/// Alta y corrección de una propiedad, en una hoja.
///
/// Devuelve el id de la propiedad, o `null` si se canceló. Es hoja y no pantalla
/// porque se abre desde adentro de otro formulario —el alta de obra de
/// SPEC-0005— y mandar a pantalla completa perdería lo que ya estaba escrito.
///
/// `site` en `null` es alta; con valor, corrección.
Future<String?> showSiteFormSheet(
  BuildContext context, {
  required String customerId,
  SiteSummary? site,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SiteFormSheet(customerId: customerId, site: site),
  );
}

class _SiteFormSheet extends ConsumerStatefulWidget {
  const _SiteFormSheet({required this.customerId, this.site});

  final String customerId;
  final SiteSummary? site;

  @override
  ConsumerState<_SiteFormSheet> createState() => _SiteFormSheetState();
}

class _SiteFormSheetState extends ConsumerState<_SiteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final AddressFormControllers _direccion;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _direccion = AddressFormControllers(initial: widget.site?.address);
  }

  @override
  void dispose() {
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _guardando) return;

    final direccion = _direccion.toDto();
    if (direccion == null) return;

    setState(() => _guardando = true);
    final repo = ref.read(customerRepositoryProvider);

    // La escritura es local: se aplica al instante y se encola. No hay estado de
    // espera de red que mostrar porque no se espera a la red.
    final id = widget.site == null
        ? await repo.addSite(widget.customerId, direccion)
        : await repo.updateSite(widget.site!.id, direccion).then(
            (_) => widget.site!.id,
          );

    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FormSheet(
      title: widget.site == null ? l10n.siteNewTitle : l10n.siteEditTitle,
      formKey: _formKey,
      onSave: _guardando ? null : _guardar,
      saveLabel: widget.site == null ? l10n.actionAdd : l10n.actionSave,
      children: [
        Text(
          l10n.customerFirstSiteHelp,
          style: context.texts.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.spacing.md),
        AddressFields(controllers: _direccion),
        // Solo en corrección: fijar el punto necesita una propiedad que ya
        // exista, porque se guarda contra su id.
        if (widget.site != null) ...[
          SizedBox(height: context.spacing.xl),
          SiteLocationBlock(site: widget.site!),
        ],
      ],
    );
  }
}
