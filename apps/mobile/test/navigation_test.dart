import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/core/navigation/last_destination_store.dart';
import 'package:snapline/core/session/session_storage.dart';
import 'package:snapline/core/theme/app_theme.dart';
import 'package:snapline/main.dart';

import 'support/fakes.dart';

/// SPEC-0003. Nada de acá toca la red: la estructura sale de la sesión guardada,
/// que es justamente lo que la hace funcionar sin señal.
void main() {
  Widget app({
    AuthMembershipDtoRole role = AuthMembershipDtoRole.owner,
    List<String>? permissions,
    AppDestination? lastDestination,
    AuthUserDtoLocale locale = AuthUserDtoLocale.es,
  }) {
    return ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(
          FakeSessionStorage(
            buildSession(
              role: role,
              permissions: permissions,
              locale: locale,
            ),
          ),
        ),
        lastDestinationStoreProvider.overrideWithValue(
          FakeLastDestinationStore(lastDestination),
        ),
      ],
      child: const SnaplineApp(),
    );
  }

  /// Los labels de la barra inferior, en el orden en que se dibujan.
  List<String> ejes(WidgetTester tester) {
    return tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destino) => destino.label)
        .toList();
  }

  group('barra por rol', () {
    testWidgets('un OWNER ve cuatro ejes de negocio', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(ejes(tester), [
        'Proyectos',
        'Clientes',
        'Reportes',
        'Facturación',
      ]);
    });

    // Fotos y Horas viven dentro de cada obra, que es donde significan algo.
    testWidgets('un OWNER no tiene pestañas globales de Fotos ni de Horas', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(ejes(tester), isNot(contains('Fotos')));
      expect(ejes(tester), isNot(contains('Horas')));
      expect(ejes(tester), isNot(contains('Mis horas')));
    });

    testWidgets('un WORKER ve exactamente dos y ninguna es la cartera', (
      tester,
    ) async {
      await tester.pumpWidget(app(role: AuthMembershipDtoRole.worker));
      await tester.pumpAndSettle();

      expect(ejes(tester), ['Hoy', 'Fotos']);
      expect(ejes(tester), isNot(contains('Proyectos')));
    });

    testWidgets('un FOREMAN ve tres, incluida Cuadrilla', (tester) async {
      await tester.pumpWidget(app(role: AuthMembershipDtoRole.foreman));
      await tester.pumpAndSettle();

      expect(ejes(tester), ['Hoy', 'Cuadrilla', 'Fotos']);
    });

    // El dominio le da cero acceso a fotos, y `media.read` no lo incluye.
    testWidgets('un ACCOUNTANT no ve la pestaña de Fotos', (tester) async {
      await tester.pumpWidget(app(role: AuthMembershipDtoRole.accountant));
      await tester.pumpAndSettle();

      expect(ejes(tester), ['Reportes', 'Facturación']);
      expect(ejes(tester), isNot(contains('Fotos')));
    });

    testWidgets('ningún rol ve menos de dos ni más de cuatro', (tester) async {
      for (final role in AuthMembershipDtoRole.$valuesDefined) {
        await tester.pumpWidget(app(role: role));
        await tester.pumpAndSettle();

        final cantidad = ejes(tester).length;
        expect(
          cantidad,
          inInclusiveRange(minDestinations, maxDestinations),
          reason: '$role vio $cantidad ejes',
        );
      }
    });
  });

  group('los permisos filtran', () {
    // Un permiso que cambia en el servidor no puede dejar una pestaña que lleve
    // a un 403: el destino simplemente no se dibuja.
    testWidgets('un destino sin su permiso no se dibuja', (tester) async {
      await tester.pumpWidget(
        app(
          permissions: permisosOwner
              .where((permiso) => permiso != 'billing.read')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(ejes(tester), ['Proyectos', 'Clientes', 'Reportes']);
    });

    testWidgets('con un solo eje no se muestra barra', (tester) async {
      await tester.pumpWidget(
        app(permissions: const ['reports.read', 'profile.write']),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(AppBar, 'Reportes'), findsOneWidget);
    });
  });

  group('el proyecto es el contenedor', () {
    Future<void> abrirProyecto(WidgetTester tester, String nombre) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
    }

    testWidgets('entrar a una obra muestra Avance, Fotos, Horas y Detalle', (
      tester,
    ) async {
      await abrirProyecto(tester, 'Obra de ejemplo 1');

      expect(find.byType(TabBar), findsOneWidget);
      for (final tab in ['Avance', 'Fotos', 'Horas', 'Detalle']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
    });

    // El timeline no cambia de forma: simplemente termina.
    testWidgets('un proyecto terminado muestra las mismas cuatro tabs', (
      tester,
    ) async {
      await abrirProyecto(tester, 'Obra de ejemplo 4');

      expect(find.text('Terminado'), findsOneWidget);
      for (final tab in ['Avance', 'Fotos', 'Horas', 'Detalle']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
    });

    testWidgets('las tabs se desplazan, nunca se apilan en dos filas', (
      tester,
    ) async {
      await abrirProyecto(tester, 'Obra de ejemplo 1');

      final barra = tester.widget<TabBar>(find.byType(TabBar));
      expect(barra.isScrollable, isTrue);
    });
  });

  group('el estado se conserva', () {
    testWidgets('cambiar de pestaña y volver conserva el scroll', (
      tester,
    ) async {
      await tester.pumpWidget(app(role: AuthMembershipDtoRole.worker));
      await tester.pumpAndSettle();

      // Hoy arranca arriba de todo.
      expect(find.text('Elemento de ejemplo 1'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Elemento de ejemplo 1'), findsNothing);

      await tester.tap(find.text('Fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();

      expect(
        find.text('Elemento de ejemplo 1'),
        findsNothing,
        reason: 'volver a Hoy rebobinó la lista al principio',
      );
    });

    testWidgets('reabrir vuelve a la última pestaña usada', (tester) async {
      await tester.pumpWidget(app(lastDestination: AppDestination.billing));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Facturación'), findsOneWidget);
    });

    testWidgets('tocar una pestaña la recuerda', (tester) async {
      final store = FakeLastDestinationStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(
              FakeSessionStorage(buildSession()),
            ),
            lastDestinationStoreProvider.overrideWithValue(store),
          ],
          child: const SnaplineApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reportes'));
      await tester.pumpAndSettle();

      expect(store.destination, AppDestination.reports);
    });

    // El teléfono es de la empresa y lo usa más de una persona: la pestaña que
    // dejó el dueño no puede dejar al trabajador en una pantalla que no tiene.
    testWidgets('una pestaña que el rol de ahora no tiene cae en la primera', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          role: AuthMembershipDtoRole.worker,
          lastDestination: AppDestination.billing,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Hoy'), findsOneWidget);
    });
  });

  group('la regla del naranja', () {
    // Una pestaña activa en `primary` pondría dos naranjas en cualquier
    // pantalla que además tenga un CTA, y entonces ninguno sería la acción.
    for (final (nombre, theme) in [
      ('claro', AppTheme.light),
      ('oscuro', AppTheme.dark),
    ]) {
      test('$nombre: la pestaña activa no usa primary', () {
        final scheme = theme.colorScheme;
        final barra = theme.navigationBarTheme;

        expect(barra.indicatorColor, scheme.primaryContainer);
        expect(barra.indicatorColor, isNot(scheme.primary));

        final iconoActivo = barra.iconTheme!.resolve({WidgetState.selected});
        expect(iconoActivo!.color, scheme.onPrimaryContainer);
        expect(iconoActivo.color, isNot(scheme.primary));

        final labelActivo = barra.labelTextStyle!.resolve({
          WidgetState.selected,
        });
        expect(labelActivo!.color, scheme.onPrimaryContainer);
      });

      test('$nombre: las tabs del proyecto tampoco', () {
        final scheme = theme.colorScheme;
        final tabs = theme.tabBarTheme;

        expect(tabs.labelColor, scheme.onPrimaryContainer);
        expect(tabs.labelColor, isNot(scheme.primary));
        expect(tabs.unselectedLabelColor, scheme.onSurfaceVariant);
      });

      test('$nombre: el label se muestra siempre, nunca solo el icono', () {
        expect(
          theme.navigationBarTheme.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysShow,
        );
      });
    }
  });

  group('la estructura no consulta al servidor', () {
    // Los permisos cacheados son conveniencia de interfaz: que el token esté
    // vencido no cambia lo que se dibuja.
    testWidgets('con el token vencido la barra se arma igual', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(
              FakeSessionStorage(
                buildSession(
                  expiresAt: DateTime.now().subtract(const Duration(days: 3)),
                ),
              ),
            ),
            lastDestinationStoreProvider.overrideWithValue(
              FakeLastDestinationStore(),
            ),
          ],
          child: const SnaplineApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(ejes(tester).length, 4);
    });
  });

  group('nada quemado', () {
    testWidgets('los ejes de un usuario en inglés salen en inglés', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: AuthUserDtoLocale.en));
      await tester.pumpAndSettle();

      expect(ejes(tester), ['Projects', 'Customers', 'Reports', 'Billing']);
    });

    testWidgets('los de un usuario en español salen en español', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: AuthUserDtoLocale.es));
      await tester.pumpAndSettle();

      expect(ejes(tester), [
        'Proyectos',
        'Clientes',
        'Reportes',
        'Facturación',
      ]);
    });

    testWidgets('las tabs de la obra también', (tester) async {
      await tester.pumpWidget(app(locale: AuthUserDtoLocale.en));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sample project 1'));
      await tester.pumpAndSettle();

      for (final tab in ['Progress', 'Photos', 'Hours', 'Details']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
    });
  });
}
