import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'project_status_display.dart';
import 'sample_projects.dart';

/// Una obra en la cartera.
///
/// El estado va arriba y solo, no al lado del título: es lo primero que se
/// busca al escanear la lista, y en una fila compartida se aprieta apenas el
/// nombre de la obra es largo o el idioma es español.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});

  final SampleProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final radio = BorderRadius.circular(spacing.radiusLg);

    return Material(
      color: colors.surface,
      borderRadius: radio,
      child: InkWell(
        onTap: onTap,
        borderRadius: radio,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(color: colors.outline),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(
                  tone: project.status.tone,
                  label: project.status.label(l10n),
                  icon: project.status.icon,
                ),
                SizedBox(height: spacing.md),
                Text(
                  project.name,
                  style: context.texts.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacing.xs),
                Text(
                  project.customer,
                  style: context.texts.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacing.sm),
                _Dato(icon: Icons.place_outlined, text: project.site),
                SizedBox(height: spacing.md),
                Divider(height: 1, color: colors.outline),
                SizedBox(height: spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _Dato(
                        icon: Icons.groups_outlined,
                        text: project.crew ?? l10n.projectNoCrew,
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    _Dato(
                      icon: Icons.photo_library_outlined,
                      text: l10n.projectPhotoCount(project.photoCount),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icono y texto atenuados: los datos de apoyo de la card no compiten con el
/// nombre de la obra.
class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final atenuado = context.colors.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: spacing.lg, color: atenuado),
        SizedBox(width: spacing.sm),
        Flexible(
          child: Text(
            text,
            style: context.texts.bodySmall?.copyWith(color: atenuado),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
