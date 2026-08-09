import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dev/theme_preview_screen.dart';
import '../../features/home/home_screen.dart';
import '../session/session_controller.dart';
import '../widgets/splash_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const home = '/';
  static const login = '/login';
  static const themePreview = '/dev/theme';
}

/// Vuelve a evaluar las rutas cada vez que cambia la sesión, así entrar y salir
/// no necesitan que ninguna pantalla navegue a mano.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final ubicacion = state.matchedLocation;

      // Las pantallas de /dev/ no pasan por la sesión: son herramientas.
      if (ubicacion.startsWith('/dev/')) return null;

      // Todavía leyendo el almacenamiento seguro: se espera en el splash, o la
      // app parpadearía en login antes de saber que sí había sesión.
      if (session.isLoading) {
        return ubicacion == Routes.splash ? null : Routes.splash;
      }

      final hasSession = session.value != null;
      final destino = hasSession ? Routes.home : Routes.login;

      if (ubicacion == Routes.splash) return destino;
      if (!hasSession && ubicacion != Routes.login) return Routes.login;
      if (hasSession && ubicacion == Routes.login) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
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
    ],
  );
});
