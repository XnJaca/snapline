import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/project_status.dart';
import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import 'project_card.dart';
import 'project_status_display.dart';
import 'sample_projects.dart';

/// La cartera del dueño: **solo lo que está en obra ahora**.
///
/// Lo agendado, lo pausado y lo cerrado se consulta, no se vigila, así que sale
/// de la pantalla principal y vive detrás de "ver todas". Andamiaje hasta que la
/// lista tenga sus datos.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final enProceso = inProgressSampleProjects;

    return AppScaffold(
      title: AppDestination.projects.label(l10n),
      body: enProceso.isEmpty
          ? EmptyState(
              icon: AppDestination.projects.icon,
              message: l10n.projectsEmptyActive,
              action: const _VerTodas(),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.md,
                spacing.lg,
                spacing.xxl,
              ),
              children: [
                SectionHeader(
                  title: l10n.projectsActiveTitle,
                  subtitle: l10n.projectsCount(enProceso.length),
                  action: _VerTodas(compacto: true),
                ),
                SizedBox(height: spacing.md),
                for (final proyecto in enProceso) ...[
                  ProjectCard(
                    project: proyecto,
                    onTap: () => context.push(proyecto.location),
                  ),
                  SizedBox(height: spacing.md),
                ],
              ],
            ),
    );
  }
}

/// Secundario a propósito: la acción primaria de esta pantalla va a ser crear
/// una obra, y el naranja sólido es de una sola cosa por pantalla.
class _VerTodas extends StatelessWidget {
  const _VerTodas({this.compacto = false});

  /// Junto al encabezado va compacto; en el estado vacío ocupa el ancho, que
  /// ahí sí es la única cosa que se puede hacer.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final label = Text(AppLocalizations.of(context).projectsViewAll);
    void abrir() => context.push(AllProjectsScreen.route);

    if (compacto) {
      return TextButton(onPressed: abrir, child: label);
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.filter_list),
      label: label,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(spacing.touchTargetMin),
      ),
      onPressed: abrir,
    );
  }
}

/// Los siete estados del dominio más "todas". Se desplazan: apilarlos en dos
/// filas comería la pantalla que vino a verse.
class _Filtros extends StatelessWidget {
  const _Filtros({required this.seleccionado, required this.onChanged});

  final ProjectStatus? seleccionado;
  final ValueChanged<ProjectStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;

    return SizedBox(
      height: spacing.touchTargetPrimary,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        children: [
          Center(
            child: FilterChip(
              label: Text(l10n.projectsFilterAll),
              selected: seleccionado == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final estado in projectStatusLifecycle)
            Padding(
              padding: EdgeInsets.only(left: spacing.sm),
              child: Center(
                child: FilterChip(
                  // Explícito: por defecto el icono de un chip sale en
                  // `primary`, y eso mete naranja saturado en cada filtro.
                  avatar: Icon(
                    estado.icon,
                    size: spacing.lg,
                    color: seleccionado == estado
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                  label: Text(estado.label(l10n)),
                  selected: seleccionado == estado,
                  onSelected: (_) => onChanged(estado),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Todas las obras, filtrables por estado. Acá sí aparecen las terminadas y las
/// canceladas, que es de lo que esta pantalla existe.
class AllProjectsScreen extends StatefulWidget {
  const AllProjectsScreen({super.key});

  static const route = '/projects/all';

  @override
  State<AllProjectsScreen> createState() => _AllProjectsScreenState();
}

class _AllProjectsScreenState extends State<AllProjectsScreen> {
  /// `null` es "todas": el filtro arranca sin recortar nada.
  ProjectStatus? _filtro;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final visibles = _filtro == null
        ? sampleProjects
        : sampleProjects.where((p) => p.status == _filtro).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        title: Text(l10n.projectsAllTitle),
      ),
      body: Column(
        children: [
          _Filtros(
            seleccionado: _filtro,
            onChanged: (estado) => setState(() => _filtro = estado),
          ),
          Divider(height: 1, color: colors.outline),
          Expanded(
            child: visibles.isEmpty
                ? EmptyState(
                    icon: Icons.filter_list_off,
                    message: l10n.projectsEmptyFiltered,
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      spacing.lg,
                      spacing.lg,
                      spacing.lg,
                      spacing.xxl,
                    ),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => SizedBox(height: spacing.md),
                    itemBuilder: (context, index) => ProjectCard(
                      project: visibles[index],
                      onTap: () => context.push(visibles[index].location),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
