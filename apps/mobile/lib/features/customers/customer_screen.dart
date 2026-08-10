import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/customer_source.dart';
import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/local/address_json.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/app_localizations.dart';
import '../projects/project_card.dart';
import 'customer_form_screen.dart';
import 'customer_source_display.dart';
import 'site_form_sheet.dart';

/// La ficha de un cliente: sus datos, sus propiedades y sus obras.
///
/// Las tres cosas en una pantalla porque son la misma pregunta —¿quién es y qué
/// le estamos haciendo?— y repartirlas en pestañas obliga a recordar en cuál
/// estaba cada dato.
class CustomerScreen extends ConsumerWidget {
  const CustomerScreen({super.key, required this.customerId});

  static const route = '/customers/:customerId';

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    final consulta = ref.watch(customerByIdProvider(customerId));
    final cliente = consulta.value;
    final propiedades =
        ref.watch(customerSitesProvider(customerId)).value ??
        const <SiteSummary>[];
    final obras =
        ref.watch(projectsByCustomerProvider(customerId)).value ??
        const <ProjectSummary>[];

    final barra = AppBar(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        // Se puede llegar por enlace directo, y ahí no hay a dónde volver.
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppDestination.customers.route),
      ),
      title: Text(cliente?.displayName ?? l10n.navCustomers),
      actions: [
        if (cliente != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.customerEdit,
            onPressed: () =>
                context.push(CustomerFormScreen.editRoute(customerId)),
          ),
      ],
    );

    if (cliente == null) {
      // Sin `hasValue` la pantalla anuncia "no está" en el frame que va entre
      // abrirla y la primera emisión del stream, y se ve como un error.
      return Scaffold(
        appBar: barra,
        body: consulta.hasValue
            ? EmptyState(
                icon: Icons.person_off_outlined,
                message: l10n.customerNotFound,
              )
            : const SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: barra,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.lg,
          spacing.lg,
          spacing.xxl,
        ),
        children: [
          _Datos(customer: cliente),
          SizedBox(height: spacing.xl),
          SectionHeader(
            title: l10n.customerSectionSites,
            action: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.customerAddSite),
              onPressed: () =>
                  showSiteFormSheet(context, customerId: customerId),
            ),
          ),
          SizedBox(height: spacing.md),
          if (propiedades.isEmpty)
            _Vacio(message: l10n.customerNoSites)
          else
            for (final propiedad in propiedades) ...[
              _Propiedad(site: propiedad),
              SizedBox(height: spacing.sm),
            ],
          SizedBox(height: spacing.lg),
          SectionHeader(title: l10n.customerSectionProjects),
          SizedBox(height: spacing.md),
          if (obras.isEmpty)
            _Vacio(message: l10n.customerNoProjects)
          else
            for (final obra in obras) ...[
              ProjectCard(
                project: obra,
                onTap: () => context.push('/projects/${obra.id}'),
              ),
              SizedBox(height: spacing.md),
            ],
        ],
      ),
    );
  }
}

/// Los datos del cliente, con lo que decide si sus obras se pueden publicar
/// arriba de todo.
class _Datos extends StatelessWidget {
  const _Datos({required this.customer});

  final CustomerDetail customer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    final fuente = customer.source == null
        ? null
        : CustomerSource.fromJson(customer.source!).label(l10n);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(spacing.radiusMd),
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              // Regla 17: es lo único que habilita publicar, y el móvil lo
              // muestra sin poder tocarlo — otorgarlo necesita el papel firmado.
              StatusChip(
                tone: customer.hasPhotoRelease
                    ? StatusTone.success
                    : StatusTone.warning,
                label: customer.hasPhotoRelease
                    ? l10n.customerPhotoReleaseGranted
                    : l10n.customerPhotoReleaseMissing,
                icon: customer.hasPhotoRelease
                    ? Icons.verified_outlined
                    : Icons.no_photography_outlined,
              ),
              if (customer.pending)
                StatusChip(
                  tone: StatusTone.info,
                  label: l10n.customerPendingSync,
                  icon: Icons.cloud_upload_outlined,
                ),
            ],
          ),
          if (!customer.hasPhotoRelease) ...[
            SizedBox(height: spacing.sm),
            Text(
              l10n.customerPhotoReleaseHelp,
              style: context.texts.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: spacing.md),
          _Dato(label: l10n.customerFieldPhone, value: customer.phone),
          _Dato(label: l10n.customerFieldEmail, value: customer.email),
          _Dato(
            label: l10n.customerFieldCompanyName,
            value: customer.companyName,
          ),
          _Dato(label: l10n.customerFieldFirstName, value: customer.firstName),
          _Dato(label: l10n.customerFieldLastName, value: customer.lastName),
          _Dato(label: l10n.customerFieldSource, value: fuente),
          _Dato(
            label: l10n.customerSectionBillingAddress,
            value: customer.billingAddress == null
                ? null
                : AddressJson.oneLine(customer.billingAddress),
          ),
          _Dato(label: l10n.customerFieldNotes, value: customer.notes),
          if (!customer.canBeInvited) ...[
            SizedBox(height: spacing.sm),
            StatusChip(
              tone: StatusTone.warning,
              label: l10n.customerNoPortalAccess,
              expand: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Una fila de la ficha. Lo que no está no se dibuja: una lista de "sin definir"
/// no dice nada y empuja hacia abajo lo que sí importa.
class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: spacing.xxl * 2,
            child: Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(child: Text(value!, style: context.texts.bodyMedium)),
        ],
      ),
    );
  }
}

class _Propiedad extends StatelessWidget {
  const _Propiedad({required this.site});

  final SiteSummary site;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(spacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(spacing.radiusMd),
        onTap: () => showSiteFormSheet(
          context,
          customerId: site.customerId,
          site: site,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(spacing.radiusMd),
          ),
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            children: [
              Icon(Icons.home_work_outlined, color: colors.onSurfaceVariant),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(site.oneLine, style: context.texts.bodyMedium),
              ),
              if (site.pending) ...[
                SizedBox(width: spacing.sm),
                StatusChip(
                  tone: StatusTone.info,
                  label: l10n.customerPendingSync,
                  icon: Icons.cloud_upload_outlined,
                  subtle: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una sección vacía dice por qué está vacía y qué hacer. En blanco se lee como
/// que la app se rompió.
class _Vacio extends StatelessWidget {
  const _Vacio({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.md),
      child: Text(
        message,
        style: context.texts.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
