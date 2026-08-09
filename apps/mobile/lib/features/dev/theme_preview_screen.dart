import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/snapline_logo.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/theme/theme_providers.dart';
import '../../l10n/app_localizations.dart';

/// Verificación visual de los tokens en los dos temas y los dos idiomas.
///
/// La regla 23 pide que un componente se pruebe en claro y en oscuro; esta
/// pantalla es la herramienta para hacerlo de un vistazo. No es producto.
class ThemePreviewScreen extends ConsumerWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const SnaplineLogo(),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: l10n.settingsLanguage,
            onPressed: () {
              final current = Localizations.localeOf(context).languageCode;
              ref
                  .read(localeProvider.notifier)
                  .select(Locale(current == 'es' ? 'en' : 'es'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: l10n.themeModeSystem,
            onPressed: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              ref
                  .read(themeModeProvider.notifier)
                  .select(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(spacing.lg),
        children: [
          _Section(
            title: l10n.devThemeColors,
            child: Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                _Swatch('primary', colors.primary, colors.onPrimary),
                _Swatch('surface', colors.surface, colors.onSurface),
                _Swatch(
                  'surfaceContainerHighest',
                  colors.surfaceContainerHighest,
                  colors.onSurfaceVariant,
                ),
                _Swatch('error', colors.error, colors.onError),
              ],
            ),
          ),
          _Section(
            title: l10n.devThemeStatus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // La acción primaria es lo único naranja sólido de la pantalla.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: Text(l10n.devThemePrimaryAction),
                  ),
                ),
                SizedBox(height: spacing.md),
                Wrap(
                  spacing: spacing.sm,
                  runSpacing: spacing.sm,
                  children: const [
                    StatusChip(tone: StatusTone.warning, label: 'warning'),
                    StatusChip(tone: StatusTone.success, label: 'success'),
                    StatusChip(tone: StatusTone.danger, label: 'danger'),
                    StatusChip(tone: StatusTone.info, label: 'info'),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            title: l10n.devThemeTypography,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('08:42', style: context.texts.displaySmall),
                Text('titleLarge', style: context.texts.titleLarge),
                Text('bodyLarge', style: context.texts.bodyLarge),
                Text(
                  'bodySmall',
                  style: context.texts.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: l10n.devThemeSpacing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in <(String, double)>[
                  ('xs', spacing.xs),
                  ('sm', spacing.sm),
                  ('md', spacing.md),
                  ('lg', spacing.lg),
                  ('xl', spacing.xl),
                  ('xxl', spacing.xxl),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.xs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: spacing.xxl,
                          child: Text(label, style: context.texts.bodySmall),
                        ),
                        Container(
                          width: value,
                          height: spacing.md,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Container(
      margin: EdgeInsets.only(bottom: spacing.lg),
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(spacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.texts.titleLarge),
          SizedBox(height: spacing.md),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(spacing.radiusSm),
        border: Border.all(color: context.colors.outline),
      ),
      child: Text(
        label,
        style: context.texts.bodySmall?.copyWith(color: foreground),
      ),
    );
  }
}
