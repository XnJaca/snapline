import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dev/theme_preview_screen.dart';
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
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Vuelve a evaluar las rutas cada vez que cambia la sesión o se termina de
/// leer la última pestaña, así entrar y salir no necesitan que ninguna pantalla
/// navegue a mano.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
    ref.listen(lastDestinationProvider, (_, _) => notifyListeners());
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

      final inicial = ref.read(initialDestinationProvider);
      // Sin ningún eje en pie igual hay que aterrizar en una rama válida:
      // `RoleShell` explica lo que pasa y deja cerrar sesión.
      final entrada = (inicial ?? AppDestination.values.first).route;

      if (ubicacion == Routes.splash || ubicacion == Routes.login) {
        return entrada;
      }

      final destino = AppDestination.forLocation(ubicacion);
      if (destino == null) return entrada;

      // Un eje que este rol no tiene no se alcanza ni por enlace directo.
      final permitidos = ref.read(destinationsProvider);
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
        path: Routes.project,
        name: 'project',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProjectScreen(
          projectId: state.pathParameters['projectId']!,
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
                  builder: (context, state) => destino == AppDestination.projects
                      ? const ProjectsScreen()
                      : PlaceholderScreen(destination: destino),
                ),
              ],
            ),
        ],
      ),
    ],
  );
});
