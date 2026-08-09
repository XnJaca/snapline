import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/project_status.dart';
import '../../core/navigation/app_destination.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';
import 'project_card.dart';
import 'project_status_display.dart';
import 'sample_projects.dart';

/// La cartera del dueño, en dos pestañas: **lo que está en obra ahora** y todo
/// lo demás.
///
/// Son tabs y no un encabezado con un botón al costado porque un botón suelto
/// sobre el fondo no se lee como parte de la interfaz — flota. Las tabs anclan,
/// y además son el mismo lenguaje que ya usa el contenedor de una obra.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: AppDestination.projects.label(l10n),
        bottom: TabBar(
          // Con dos pestañas cada una se lleva media pantalla, y la pastilla a
          // ese tamaño pesa más que el contenido. El aire la ajusta al texto.
          indicatorPadding: EdgeInsets.symmetric(
            horizontal: context.spacing.xxl,
            vertical: context.spacing.sm,
          ),
          tabs: [
            Tab(text: l10n.projectsTabInProgress),
            Tab(text: l10n.projectsTabAll),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outline)),
          ),
          child: const TabBarView(
            children: [_EnProceso(), _Todas()],
          ),
        ),
      ),
    );
  }
}

class _EnProceso extends StatelessWidget {
  const _EnProceso();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enProceso = inProgressSampleProjects;

    if (enProceso.isEmpty) {
      return EmptyState(
        icon: AppDestination.projects.icon,
        message: l10n.projectsEmptyActive,
      );
    }
    return _ListaDeObras(
      storageKey: 'projects.inProgress',
      projects: enProceso,
    );
  }
}

class _Todas extends StatefulWidget {
  const _Todas();

  @override
  State<_Todas> createState() => _TodasState();
}

class _TodasState extends State<_Todas> {
  /// `null` es "todas": el filtro arranca sin recortar nada.
  ProjectStatus? _filtro;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final visibles = _filtro == null
        ? sampleProjects
        : sampleProjects.where((p) => p.status == _filtro).toList();

    return Column(
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
              : _ListaDeObras(
                  storageKey: 'projects.all',
                  projects: visibles,
                ),
        ),
      ],
    );
  }
}

class _ListaDeObras extends StatelessWidget {
  const _ListaDeObras({required this.storageKey, required this.projects});

  final String storageKey;
  final List<SampleProject> projects;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return ListView.separated(
      key: PageStorageKey<String>(storageKey),
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        spacing.xxl,
      ),
      itemCount: projects.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) => ProjectCard(
        project: projects[index],
        onTap: () => context.push(projects[index].location),
      ),
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
