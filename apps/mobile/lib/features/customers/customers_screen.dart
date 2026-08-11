import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/sync_button.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import 'customer_card.dart';
import 'customer_form_screen.dart';

/// El eje de Clientes: buscar y entrar.
///
/// El buscador va arriba y siempre visible porque el caso real es buscar a
/// alguien que llamó, no recorrer una lista. Sale de la base local, así que sin
/// señal busca igual.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _buscador = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final clientes = ref.watch(customersProvider(_query));
    final buscando = _query.trim().isNotEmpty;

    return AppScaffold(
      title: AppDestination.customers.label(l10n),
      actions: const [SyncButton()],
      body: Column(
        children: [
          SearchField(
            controller: _buscador,
            hint: l10n.customersSearchHint,
            onChanged: (valor) => setState(() => _query = valor),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(syncControllerProvider.notifier).refresh(),
              child: Builder(
                builder: (context) {
                  // Sin spinner: la base local responde al instante y un
                  // indicador infinito cuelga cualquier test que espere a que
                  // las animaciones terminen.
                  final lista = clientes.value ?? const <CustomerSummary>[];

                  if (lista.isEmpty) {
                    return ListView(
                      // Scrolleable igual, o no se puede tirar para refrescar.
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: spacing.xxl * 3),
                        EmptyState(
                          icon: buscando
                              ? Icons.search_off
                              : AppDestination.customers.icon,
                          message: buscando
                              ? l10n.customersEmptySearch
                              : l10n.customersEmpty,
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    key: const PageStorageKey<String>('customers.list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      spacing.lg,
                      spacing.lg,
                      spacing.lg,
                      // Aire para que la última card no quede bajo el botón.
                      spacing.xxl * 2,
                    ),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => SizedBox(height: spacing.md),
                    itemBuilder: (context, index) => CustomerCard(
                      customer: lista[index],
                      onTap: () => context.push('/customers/${lista[index].id}'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.customersNew),
        onPressed: () => context.push(CustomerFormScreen.newRoute),
      ),
    );
  }
}
