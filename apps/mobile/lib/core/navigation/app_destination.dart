import 'package:flutter/material.dart';

import '../../api/models/auth_membership_dto.dart';
import '../../api/models/auth_membership_dto_role.dart';
import '../../l10n/app_localizations.dart';

/// Un eje de la barra inferior.
///
/// El orden de declaración es el orden de las ramas del shell: `index` es el
/// número de rama en `StatefulShellRoute`, así que agregar un destino en el
/// medio mueve las ramas y hay que declararlo también en el router.
enum AppDestination {
  today(
    route: '/today',
    permission: 'time.clock',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
  ),
  projects(
    route: '/projects',
    permission: 'projects.read',
    icon: Icons.construction_outlined,
    selectedIcon: Icons.construction,
  ),
  crew(
    route: '/crew',
    permission: 'crews.read',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
  ),
  photos(
    route: '/photos',
    permission: 'media.read',
    icon: Icons.photo_library_outlined,
    selectedIcon: Icons.photo_library,
  ),
  customers(
    route: '/customers',
    permission: 'customers.read',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  reports(
    route: '/reports',
    permission: 'reports.read',
    icon: Icons.insert_chart_outlined,
    selectedIcon: Icons.insert_chart,
  ),
  billing(
    route: '/billing',
    permission: 'billing.read',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  );

  const AppDestination({
    required this.route,
    required this.permission,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;

  /// Lo que el destino necesita. Si no está en `membership.permissions`, no se
  /// dibuja: así un permiso que cambia en el servidor no deja una pestaña que
  /// lleve a un 403.
  final String permission;

  final IconData icon;

  /// El icono lleno distingue la pestaña activa sin depender del color.
  final IconData selectedIcon;

  String label(AppLocalizations l10n) => switch (this) {
    AppDestination.today => l10n.navToday,
    AppDestination.projects => l10n.navProjects,
    AppDestination.crew => l10n.navCrew,
    AppDestination.photos => l10n.navPhotos,
    AppDestination.customers => l10n.navCustomers,
    AppDestination.reports => l10n.navReports,
    AppDestination.billing => l10n.navBilling,
  };

  static AppDestination? fromName(String name) {
    for (final destino in values) {
      if (destino.name == name) return destino;
    }
    return null;
  }

  /// El destino cuya rama contiene esta ubicación. `/projects/abc` es de
  /// `projects`.
  static AppDestination? forLocation(String location) {
    for (final destino in values) {
      if (location == destino.route || location.startsWith('${destino.route}/')) {
        return destino;
      }
    }
    return null;
  }
}

/// Nunca menos de dos ni más de cuatro (SPEC-0003). Con uno solo no se muestra
/// barra: una pestaña única no es navegación, es ruido.
const minDestinations = 2;
const maxDestinations = 4;

/// Qué ejes ve cada rol. Es decisión de producto y por eso vive en el móvil; la
/// tabla de quién puede qué vive en el servidor y llega en `permissions`.
const _byRole = <AuthMembershipDtoRole, List<AppDestination>>{
  AuthMembershipDtoRole.owner: [
    AppDestination.projects,
    AppDestination.customers,
    AppDestination.reports,
    AppDestination.billing,
  ],
  AuthMembershipDtoRole.admin: [
    AppDestination.projects,
    AppDestination.customers,
    AppDestination.reports,
    AppDestination.billing,
  ],
  AuthMembershipDtoRole.foreman: [
    AppDestination.today,
    AppDestination.crew,
    AppDestination.photos,
  ],
  AuthMembershipDtoRole.worker: [
    AppDestination.today,
    AppDestination.photos,
  ],
  AuthMembershipDtoRole.accountant: [
    AppDestination.reports,
    AppDestination.billing,
  ],
};

/// Los ejes de una membresía: la lista de su rol, filtrada por los permisos que
/// el servidor devolvió.
///
/// Un rol que esta versión de la app no conoce cae en el orden canónico filtrado
/// por permisos, en vez de quedarse sin barra.
List<AppDestination> destinationsFor(AuthMembershipDto membership) {
  final propuestos = _byRole[membership.role] ?? AppDestination.values;
  final permisos = membership.permissions.toSet();

  return propuestos
      .where((destino) => permisos.contains(destino.permission))
      .take(maxDestinations)
      .toList(growable: false);
}
