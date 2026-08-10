import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/customers/customer_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/dev/theme_preview_screen.dart';
import '../../features/projects/all_projects_screen.dart';
import '../../features/projects/project_form_screen.dart';
import '../../features/projects/project_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/shell/role_shell.dart';
import '../navigation/app_destination.dart';
import '../navigation/navigation_providers.dart';
import '../session/session_controller.dart';
import '../widgets/placeholder_screen.dart';
import '../widgets/splash_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const themePreview = '/dev/theme';

  /// El detalle vive fuera del shell: la obra es un contenedor propio, con sus
  /// tabs, y encima de la barra de ejes no cabrían las dos.
  static const project = '/projects/:projectId';
  static const projectEdit = '/projects/:projectId/edit';

  /// Igual que la obra: la ficha del cliente es su propia pantalla, con sus
  /// secciones, y no una pestaña más.
  static const customer = '/customers/:customerId';
  static const customerEdit = '/customers/:customerId/edit';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Rutas que existen con sesión pero no pertenecen a ningún eje de la barra.
/// Sin esta lista el redirect las trata como desconocidas y las devuelve al
/// primer destino.
const _sinEje = {AccountScreen.route};

/// Vuelve a evaluar las rutas cada vez que cambia la sesión o se termina de
/// leer la última pestaña, así entrar y salir no necesitan que ninguna pantalla
/// navegue a mano.
///
/// La notificación se difiere un microtask: el cambio de sesión puede llegar
/// mientras se está construyendo el árbol —cerrar sesión desde una pantalla que
/// justo se desmonta— y avisarle a `GoRouter` en ese momento lo hace reconstruir
/// en medio de un build.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => _notificarDiferido());
    ref.listen(lastDestinationProvider, (_, _) => _notificarDiferido());
  }

  bool _dispuesto = false;

  void _notificarDiferido() {
    scheduleMicrotask(() {
      if (_dispuesto) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _dispuesto = true;
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final ubicacion = state.matchedLocation;

      // Las pantallas de /dev/ no pasan por la sesión: son herramientas.
      if (ubicacion.startsWith('/dev/')) return null;

      final session = ref.read(sessionControllerProvider);
      final ultima = ref.read(lastDestinationProvider);

      // Todavía leyendo el almacenamiento: se espera en el splash, o la app
      // parpadearía en login antes de saber que sí había sesión, y abriría en
      // el primer eje antes de saber cuál fue el último.
      if (session.isLoading || ultima.isLoading) {
        return ubicacion == Routes.splash ? null : Routes.splash;
      }

      if (session.value == null) {
        return ubicacion == Routes.login ? null : Routes.login;
      }

      // Directo de la sesión, con funciones puras: leer un provider derivado
      // desde acá lo recalcula en pleno build y termina en un refresh del
      // scope a destiempo.
      final permitidos = destinationsFor(session.value!.membership);
      final inicial = initialDestination(
        destinations: permitidos,
        last: ultima.value,
      );
      // Sin ningún eje en pie igual hay que aterrizar en una rama válida:
      // `RoleShell` explica lo que pasa y deja cerrar sesión.
      final entrada = (inicial ?? AppDestination.values.first).route;

      if (ubicacion == Routes.splash || ubicacion == Routes.login) {
        return entrada;
      }

      // Pantallas que cuelgan de la sesión pero no de ningún eje.
      if (_sinEje.contains(ubicacion)) return null;

      final destino = AppDestination.forLocation(ubicacion);
      if (destino == null) return entrada;

      // Un eje que este rol no tiene no se alcanza ni por enlace directo.
      if (permitidos.isNotEmpty && !permitidos.contains(destino)) {
        return entrada;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.themePreview,
        name: 'themePreview',
        builder: (context, state) => const ThemePreviewScreen(),
      ),
      GoRoute(
        path: AccountScreen.route,
        name: 'account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountScreen(),
      ),
      // Antes que `/projects/:projectId`, o "all" y "new" entrarían como id de
      // obra.
      GoRoute(
        path: AllProjectsScreen.route,
        name: 'allProjects',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AllProjectsScreen(),
      ),
      GoRoute(
        path: ProjectFormScreen.newRoute,
        name: 'newProject',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: Routes.projectEdit,
        name: 'editProject',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProjectFormScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),
      GoRoute(
        path: Routes.project,
        name: 'project',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProjectScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),
      // Antes que `/customers/:customerId`, o "new" entraría como id de cliente.
      GoRoute(
        path: CustomerFormScreen.newRoute,
        name: 'newCustomer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: Routes.customerEdit,
        name: 'editCustomer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CustomerFormScreen(
          customerId: state.pathParameters['customerId']!,
        ),
      ),
      GoRoute(
        path: Routes.customer,
        name: 'customer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CustomerScreen(
          customerId: state.pathParameters['customerId']!,
        ),
      ),
      // Una rama por destino, siempre las mismas: el rol decide cuáles se
      // dibujan, no cuáles existen. El orden es el de `AppDestination.values`.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RoleShell(navigationShell: navigationShell),
        branches: [
          for (final destino in AppDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destino.route,
                  builder: (context, state) => switch (destino) {
                    AppDestination.projects => const ProjectsScreen(),
                    AppDestination.customers => const CustomersScreen(),
                    _ => PlaceholderScreen(destination: destino),
                  },
                ),
              ],
            ),
        ],
      ),
    ],
  );
});
