import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/core/navigation/last_destination_store.dart';
import 'package:snapline/core/session/session_storage.dart';
import 'package:snapline/core/theme/locale_store.dart';
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

  /// Abre la pantalla de toda la cartera y, si se pide, selecciona el estado.
  ///
  /// Las pestañas de ahí llevan el conteo pegado —"Cancelado  1"—, así que se
  /// buscan por texto contenido y acotadas a la `TabBar`: el nombre del estado
  /// aparece también en el chip de cada card.
  Future<void> elegirEstado(WidgetTester tester, String estado) async {
    final pestanas = find.byType(TabBar);
    final pestana = find.descendant(
      of: pestanas,
      matching: find.textContaining(estado),
    );
    // Son ocho y se desplazan: la que se busca puede no estar construida.
    await tester.scrollUntilVisible(
      pestana,
      200,
      scrollable: find
          .descendant(of: pestanas, matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(pestana.first);
    await tester.pumpAndSettle();
    await tester.tap(pestana.first);
    await tester.pumpAndSettle();
  }

  Future<void> verTodos(WidgetTester tester, {String? estado}) async {
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    if (estado != null) await elegirEstado(tester, estado);
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
    // Los nombres de obra son datos, no interfaz: no pasan por i18n.
    Future<void> abrirProyecto(WidgetTester tester, String nombre) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
    }

    testWidgets('entrar a una obra muestra Avance, Fotos, Horas y Detalle', (
      tester,
    ) async {
      await abrirProyecto(tester, 'Kitchen remodel');

      expect(find.byType(TabBar), findsOneWidget);
      for (final tab in ['Avance', 'Fotos', 'Horas', 'Detalle']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
    });

    // El timeline no cambia de forma: simplemente termina. Una obra terminada
    // no entra en el filtro por defecto, así que se llega por "Todos".
    testWidgets('un proyecto terminado muestra las mismas cuatro tabs', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await verTodos(tester, estado: 'Terminado');
      final obra = find.text('Front porch repair');
      await tester.scrollUntilVisible(
        obra,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(obra);
      await tester.pumpAndSettle();
      await tester.tap(obra);
      await tester.pumpAndSettle();

      expect(find.text('Terminado'), findsOneWidget);
      for (final tab in ['Avance', 'Fotos', 'Horas', 'Detalle']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
    });

    // Son cuatro y entran siempre: alineadas a la izquierda dejaban un hueco
    // muerto a la derecha que se leía como que faltaba algo.
    testWidgets('las cuatro tabs se reparten el ancho', (tester) async {
      await abrirProyecto(tester, 'Kitchen remodel');

      final barra = tester.widget<TabBar>(find.byType(TabBar));
      expect(barra.isScrollable, isFalse);
      expect(barra.tabs.length, 4);
    });

    // De qué obra se trata tiene que quedar a la vista al cambiar de pestaña.
    testWidgets('la cabecera se queda al cambiar de tab', (tester) async {
      await abrirProyecto(tester, 'Kitchen remodel');

      expect(find.text('Martínez family'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Horas'));
      await tester.pumpAndSettle();
      expect(find.text('Martínez family'), findsOneWidget);
    });
  });

  group('la cartera muestra lo vivo', () {
    // Abre en lo que está en obra ahora. Lo agendado, lo pausado y lo cerrado
    // se consulta cambiando de filtro.
    testWidgets('la lista principal muestra solo lo que está en proceso', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Kitchen remodel'), findsOneWidget);
      expect(find.text('Roof replacement'), findsOneWidget);

      expect(find.text('Deck rebuild'), findsNothing, reason: 'está en pausa');
      expect(
        find.text('Bathroom addition'),
        findsNothing,
        reason: 'está agendada, no en obra',
      );
      expect(find.text('Front porch repair'), findsNothing);
      expect(find.text('Window replacement'), findsNothing);
    });


    // Lo cerrado no desaparece: vive detrás de "ver todos", que es la pantalla
    // dedicada con una pestaña por estado.
    testWidgets('"ver todos" llega a lo terminado', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await verTodos(tester, estado: 'Terminado');

      expect(find.text('Front porch repair'), findsOneWidget);
      expect(find.text('Kitchen remodel'), findsNothing);
    });

    testWidgets('cada pestaña recorta por su estado', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await verTodos(tester, estado: 'Cancelado');

      expect(find.text('Window replacement'), findsOneWidget);
      expect(find.text('Kitchen remodel'), findsNothing);
    });

    testWidgets('cambiar de pestaña cambia lo que se lista', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await verTodos(tester, estado: 'Prospecto');
      expect(find.text('Garage conversion'), findsOneWidget);

      await elegirEstado(tester, 'Estimado');
      expect(find.text('Garage conversion'), findsNothing);
      expect(find.text('Siding replacement'), findsOneWidget);
    });
  });

  group('la cuenta', () {
    Future<void> abrirCuenta(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
      await tester.pumpAndSettle();
    }

    testWidgets('es una pantalla, no una hoja', (tester) async {
      await abrirCuenta(tester);

      expect(find.widgetWithText(AppBar, 'Cuenta'), findsOneWidget);
      expect(find.text('William Ferman'), findsOneWidget);
      expect(find.text('Professional Construction LLC'), findsOneWidget);
      expect(find.text('Dueño'), findsWidgets);

      // Salir vive al final, que es donde va una acción destructiva.
      await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    // Salir dispara el redirect del router, que reconstruye el árbol entero.
    // Hacerlo sin cerrar antes esta pantalla rompía con `setState` durante el
    // build, y solo se veía corriendo la app de verdad.
    testWidgets('salir vuelve al login sin romper el árbol', (tester) async {
      await abrirCuenta(tester);

      await tester.scrollUntilVisible(find.byIcon(Icons.logout), 200);
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(NavigationBar), findsNothing);
    });

    // El idioma es por persona, y la elección tiene que sobrevivir a cerrar la
    // app: sin persistirla, al reabrir vuelve al de la cuenta.
    testWidgets('el idioma se elige y se guarda', (tester) async {
      final store = FakeLocaleStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(
              FakeSessionStorage(buildSession()),
            ),
            lastDestinationStoreProvider.overrideWithValue(
              FakeLastDestinationStore(),
            ),
            localeStoreProvider.overrideWithValue(store),
          ],
          child: const SnaplineApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('English'), 200);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Account'), findsOneWidget);
      expect(store.locale?.languageCode, 'en');
    });

    // No es cosmético: la misma app se usa en un techo con sol directo y en un
    // sótano sin luz.
    testWidgets('el tema se elige a mano', (tester) async {
      await abrirCuenta(tester);

      await tester.scrollUntilVisible(
        find.byType(SegmentedButton<ThemeMode>),
        200,
      );
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();

      final selector = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(selector.selected, {ThemeMode.dark});
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
      await tester.tap(find.text('Kitchen remodel'));
      await tester.pumpAndSettle();

      for (final tab in ['Progress', 'Photos', 'Hours', 'Details']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
    });
  });
}
