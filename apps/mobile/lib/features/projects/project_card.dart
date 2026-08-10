import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/status_chip.dart';
import 'project_status_display.dart';

/// Una obra en la cartera.
///
/// El orden es el de la pregunta que se hace quien mira: qué obra, de quién, de
/// qué se trata, dónde queda y en qué anda.
///
/// El estado va arriba, en la fila del título: es lo primero que se busca al
/// escanear la cartera, y al pie de la card quedaba sin peso. El título es
/// flexible, así que un nombre largo no lo aplasta.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});

  final ProjectSummary project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final radio = BorderRadius.circular(spacing.radiusLg);
    final descripcion = project.description;

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        project.name,
                        style: context.texts.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    StatusChip(
                      tone: project.status.tone,
                      icon: project.status.icon,
                      label: project.status.label(l10n),
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  project.customerName,
                  style: context.texts.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (descripcion != null && descripcion.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    descripcion,
                    style: context.texts.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: spacing.sm),
                _Dato(icon: Icons.place_outlined, text: project.site),

                if (project.pending) ...[
                  SizedBox(height: spacing.xs),
                  _Dato(
                    icon: Icons.cloud_upload_outlined,
                    text: l10n.projectPendingSync,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icono y texto atenuados: los datos de apoyo no compiten con el nombre.
class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final atenuado = context.colors.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: spacing.lg, color: atenuado),
        SizedBox(width: spacing.sm),
        Expanded(
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
