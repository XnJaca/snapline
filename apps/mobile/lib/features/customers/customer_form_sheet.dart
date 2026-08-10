import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/customer_repository.dart';
import '../../l10n/app_localizations.dart';
import 'customer_fields.dart';
import 'form_sheet.dart';

/// Alta de cliente en versión mínima: nombre y un contacto.
///
/// Devuelve el id del cliente creado, o `null` si se canceló. **Es lo que el
/// alta de obra de SPEC-0005 abre en línea**, con el cliente al lado y sin
/// mandar a otra pantalla. Los campos son los mismos de la ficha completa
/// —`CustomerFields` con `minimal`— y no una copia: dos juegos de campos
/// divergen.
Future<String?> showCustomerFormSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CustomerFormSheet(),
  );
}

class _CustomerFormSheet extends ConsumerStatefulWidget {
  const _CustomerFormSheet();

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final CustomerFormControllers _campos;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _campos = CustomerFormControllers();
  }

  @override
  void dispose() {
    _campos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _guardando) return;

    setState(() => _guardando = true);
    final id = await ref
        .read(customerRepositoryProvider)
        .create(_campos.toInput());

    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FormSheet(
      title: l10n.customerNewTitle,
      formKey: _formKey,
      onSave: _guardando ? null : _guardar,
      saveLabel: l10n.actionAdd,
      children: [CustomerFields(controllers: _campos, minimal: true)],
    );
  }
}
