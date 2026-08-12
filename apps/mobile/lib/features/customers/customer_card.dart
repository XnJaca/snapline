import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/app_localizations.dart';

/// Un cliente en la lista: cómo se llama, cómo se lo contacta, y si sus obras se
/// pueden publicar.
class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.customer, required this.onTap});

  final CustomerSummary customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final atenuado = colors.onSurfaceVariant;

    // El contacto es lo que se usa para llamar: teléfono primero, que es como se
    // contacta a un cliente parado en una obra.
    final contacto = customer.phone?.isNotEmpty == true
        ? customer.phone!
        : (customer.email ?? '');

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(spacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(spacing.radiusMd),
          ),
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.displayName,
                style: context.texts.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (customer.companyName?.isNotEmpty == true) ...[
                SizedBox(height: spacing.xs),
                Text(
                  customer.companyName!,
                  style: context.texts.bodySmall?.copyWith(color: atenuado),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (contacto.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  contacto,
                  style: context.texts.bodySmall?.copyWith(color: atenuado),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (customer.pending) ...[
                SizedBox(height: spacing.sm),
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
