import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/auth_membership_dto_role.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/theme_providers.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';

/// La cuenta: quién está adentro, cómo se ve la app y cómo salir.
///
/// Las configuraciones que falten —idioma, notificaciones— entran acá cuando
/// tengan su spec. Es el lugar, no una pantalla más.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const route = '/account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        title: Text(l10n.accountTitle),
      ),
      body: session == null
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.lg,
                spacing.lg,
                spacing.xxl,
              ),
              children: [
                _Identidad(
                  name: session.user.name,
                  role: session.membership.role.label(l10n),
                ),
                SizedBox(height: spacing.xl),

                SectionHeader(title: l10n.accountSectionCompany),
                SizedBox(height: spacing.sm),
                _Ficha(
                  filas: [
                    (
                      Icons.business_outlined,
                      l10n.accountCompanyName,
                      session.membership.companyName,
                    ),
                    (
                      Icons.badge_outlined,
                      l10n.accountRole,
                      session.membership.role.label(l10n),
                    ),
                  ],
                ),
                SizedBox(height: spacing.xl),

                SectionHeader(title: l10n.accountSectionContact),
                SizedBox(height: spacing.sm),
                _Ficha(
                  filas: [
                    (
                      Icons.mail_outline,
                      l10n.accountEmail,
                      session.user.email ?? l10n.accountNoEmail,
                    ),
                    (
                      Icons.phone_outlined,
                      l10n.accountPhone,
                      session.user.phone ?? l10n.accountNoEmail,
                    ),
                  ],
                ),
                SizedBox(height: spacing.xl),

                SectionHeader(title: l10n.accountSectionAppearance),
                SizedBox(height: spacing.sm),
                const _SelectorDeTema(),
                SizedBox(height: spacing.xxl),

                OutlinedButton.icon(
                  // Salir no es la acción primaria de ninguna pantalla: sólida
                  // la dejaría compitiendo con el naranja que sí lo es.
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.authSignOut),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error),
                    minimumSize: Size.fromHeight(spacing.touchTargetPrimary),
                  ),
                  onPressed: () =>
                      ref.read(sessionControllerProvider.notifier).signOut(),
                ),
              ],
            ),
    );
  }
}

class _Identidad extends StatelessWidget {
  const _Identidad({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final inicial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: spacing.touchTargetPrimary,
          height: spacing.touchTargetPrimary,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            inicial,
            style: context.texts.titleLarge?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        SizedBox(width: spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: context.texts.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing.xs),
              Text(
                role,
                style: context.texts.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filas de dato dentro de un contenedor con borde: agrupa lo que va junto en
/// vez de dejar texto suelto sobre el fondo.
class _Ficha extends StatelessWidget {
  const _Ficha({required this.filas});

  final List<(IconData, String, String)> filas;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(spacing.radiusLg),
      ),
      child: Column(
        children: [
          for (final (indice, (icono, etiqueta, valor)) in filas.indexed) ...[
            if (indice > 0) Divider(height: 1, color: colors.outline),
            Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Row(
                children: [
                  Icon(icono, color: colors.onSurfaceVariant),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          etiqueta,
                          style: context.texts.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        Text(valor, style: context.texts.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La app se usa en un techo con sol directo y en un sótano sin luz: el tema no
/// es cosmético, así que se elige a mano y no solo por el sistema.
class _SelectorDeTema extends ConsumerWidget {
  const _SelectorDeTema();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final actual = ref.watch(themeModeProvider);

    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto_outlined),
          label: Text(l10n.themeModeSystem),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(l10n.themeModeLight),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(l10n.themeModeDark),
        ),
      ],
      selected: {actual},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        minimumSize: Size.fromHeight(spacing.touchTargetMin),
      ),
      onSelectionChanged: (seleccion) =>
          ref.read(themeModeProvider.notifier).select(seleccion.first),
    );
  }
}

extension on AuthMembershipDtoRole {
  String label(AppLocalizations l10n) => switch (this) {
    AuthMembershipDtoRole.owner => l10n.roleOwner,
    AuthMembershipDtoRole.admin => l10n.roleAdmin,
    AuthMembershipDtoRole.foreman => l10n.roleForeman,
    AuthMembershipDtoRole.worker => l10n.roleWorker,
    AuthMembershipDtoRole.accountant => l10n.roleAccountant,
    AuthMembershipDtoRole.$unknown => l10n.accountRole,
  };
}
