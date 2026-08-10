import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/api/models/project_status.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/features/projects/project_form_screen.dart';
import 'package:snapline/features/projects/project_transitions.dart';

import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// SPEC-0005: el alta y la corrección de una obra.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = testDatabase();
    await seedCustomer(
      db,
      id: 'c1',
      displayName: 'Ana Martínez',
      siteLine1: '412 Ellsworth Dr',
    );
    await seedCustomer(db, id: 'c2', displayName: 'Bob Smith');
  });

  tearDown(() => db.close());

  Widget app({AuthUserDtoLocale locale = AuthUserDtoLocale.es}) => testApp(
    db: db,
    session: buildSession(locale: locale),
    lastDestination: AppDestination.projects,
  );

  Future<void> abrirAlta(WidgetTester tester) async {
    await pumpApp(tester, app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva obra').first);
    await tester.pumpAndSettle();
  }

  group('el alta', () {
    testWithApp('la acción primaria de la cartera abre el formulario', (
      tester,
    ) async {
      await abrirAlta(tester);

      expect(find.byType(ProjectFormScreen), findsOne);
      expect(find.text('Nombre de la obra (obligatorio)'), findsOne);
    });

    testWithApp('no guarda sin cliente ni propiedad', (tester) async {
      await abrirAlta(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la obra (obligatorio)'),
        'Sin cliente',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Los selectores no son campos de texto, así que su falta no la caza el
      // `Form`: se muestra igual y no se guarda nada.
      expect(find.text('Falta elegir el cliente'), findsOne);
      expect(find.byType(ProjectFormScreen), findsOne);
      expect(await db.select(db.projects).get(), isEmpty);
    });

    testWithApp('la propiedad espera a que haya cliente', (tester) async {
      await abrirAlta(tester);

      // El `site_id` tiene que pertenecer al `customer_id`, así que sin cliente
      // no hay de dónde elegir — y decirlo es más útil que un campo muerto.
      expect(find.text('Elija primero el cliente'), findsOne);
    });
  });

  group('el selector de propiedad', () {
    Future<void> elegirCliente(WidgetTester tester, String nombre) async {
      await tester.tap(find.text('Cliente (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
    }

    testWithApp('ofrece solo las propiedades del cliente elegido', (
      tester,
    ) async {
      await abrirAlta(tester);
      await elegirCliente(tester, 'Ana Martínez');

      await tester.tap(find.text('Propiedad (obligatorio)'));
      await tester.pumpAndSettle();

      // La única del cliente elegido, y la del otro cliente no aparece.
      expect(find.text('412 Ellsworth Dr, Silver Spring, MD'), findsWidgets);
      expect(find.text('Elija una propiedad'), findsOne); // el título de la hoja
    });

    testWithApp('un cliente sin propiedades lo dice', (tester) async {
      await abrirAlta(tester);
      await elegirCliente(tester, 'Bob Smith');

      expect(
        find.text('Este cliente todavía no tiene propiedades. Agregue una.'),
        findsOne,
      );
    });

    testWithApp('cambiar de cliente vacía la propiedad', (tester) async {
      await abrirAlta(tester);
      await elegirCliente(tester, 'Ana Martínez');

      await tester.tap(find.text('Propiedad (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('412 Ellsworth Dr, Silver Spring, MD'));
      await tester.pumpAndSettle();
      expect(find.text('412 Ellsworth Dr, Silver Spring, MD'), findsOne);

      // Dejarla puesta crearía la obra en la casa de otra persona.
      await elegirCliente(tester, 'Bob Smith');
      expect(find.text('412 Ellsworth Dr, Silver Spring, MD'), findsNothing);
    });
  });

  group('crear sin salir del alta', () {
    testWithApp('el cliente nuevo se crea y queda elegido', (tester) async {
      await abrirAlta(tester);

      await tester.tap(find.text('Cliente (obligatorio)'));
      await tester.pumpAndSettle();
      // El "＋ nuevo" abre el formulario de SPEC-0006, no una copia.
      await tester.tap(find.text('Nuevo cliente').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
        'Cliente en la obra',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      // Vuelve al alta con el cliente ya puesto: sin pasar por otra pantalla.
      expect(find.byType(ProjectFormScreen), findsOne);
      expect(find.text('Cliente en la obra'), findsOne);
    });

    testWithApp('la propiedad nueva se crea y queda elegida', (tester) async {
      await abrirAlta(tester);
      await tester.tap(find.text('Cliente (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob Smith'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Propiedad (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva propiedad').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calle y número (obligatorio)'),
        '9800 Georgia Ave',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad (obligatorio)'),
        'Silver Spring',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Estado (obligatorio)'),
        'MD',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código postal (obligatorio)'),
        '20902',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectFormScreen), findsOne);
      expect(find.textContaining('9800 Georgia Ave'), findsWidgets);
    });

    testWithApp('el trío completo deja la obra guardada y pendiente', (
      tester,
    ) async {
      await abrirAlta(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la obra (obligatorio)'),
        'Obra del trío',
      );
      await tester.tap(find.text('Cliente (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Martínez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Propiedad (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('412 Ellsworth Dr, Silver Spring, MD'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // El formulario se reemplaza por la obra: el back vuelve a la cartera.
      expect(find.byType(ProjectFormScreen), findsNothing);
      final obras = await db.select(db.projects).get();
      expect(obras, hasLength(1));
      expect(obras.first.name, 'Obra del trío');
      expect(obras.first.clientVisibilityMode, 'STAGES');
    });
  });

  // El criterio estrella del spec: los tres, en una sola pasada, sin salir.
  group('cliente, propiedad y obra sin salir del alta', () {
    testWithApp('los tres se crean en el mismo formulario', (tester) async {
      await abrirAlta(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la obra (obligatorio)'),
        'Obra de punta a punta',
      );

      // 1) El cliente, en línea.
      await tester.tap(find.text('Cliente (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
        'Cliente al lado',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      // 2) Su propiedad, también en línea y sin volver a elegir cliente.
      await tester.tap(find.text('Propiedad (obligatorio)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva propiedad').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calle y número (obligatorio)'),
        '100 Main St',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ciudad (obligatorio)'),
        'Baltimore',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Estado (obligatorio)'),
        'MD',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código postal (obligatorio)'),
        '21201',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      // 3) Y la obra.
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final cliente = await db.select(db.customers).get();
      final obra = await db.select(db.projects).get();
      final sitio = await db.select(db.sites).get();

      final nuevo = cliente.where((c) => c.displayName == 'Cliente al lado').single;
      final suSitio = sitio.where((s) => s.customerId == nuevo.id).single;
      expect(obra, hasLength(1));
      expect(obra.first.customerId, nuevo.id);
      expect(obra.first.siteId, suSitio.id);

      // Las tres en la bandeja, y en el orden en que se crearon: la obra no puede
      // aplicarse antes que el cliente del que cuelga.
      final pendientes = await Outbox(db, const Uuid()).pending();
      final tipos = pendientes.map((o) => o.type).toList();
      expect(tipos.indexOf('customer.create'), lessThan(tipos.indexOf('site.create')));
      expect(tipos.indexOf('site.create'), lessThan(tipos.indexOf('project.create')));
    });
  });

  group('el selector de estado', () {
    testWithApp('dibuja solo las transiciones válidas', (tester) async {
      await seedProject(
        db,
        id: 'p1',
        name: 'Obra agendada',
        customerName: 'Ana Martínez',
        status: ProjectStatus.scheduled,
      );
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      // La obra agendada no está en la cartera: se llega por "ver todos".
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obra agendada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();

      // Desde agendada: en proceso, en pausa y cancelado. Nada más.
      expect(find.widgetWithText(OutlinedButton, 'En proceso'), findsOne);
      expect(find.widgetWithText(OutlinedButton, 'En pausa'), findsOne);
      expect(find.widgetWithText(OutlinedButton, 'Cancelado'), findsOne);
      // Un botón que el servidor va a rechazar no debería estar dibujado.
      expect(find.widgetWithText(OutlinedButton, 'Terminado'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Prospecto'), findsNothing);
    });

    testWithApp('una obra terminada no ofrece ninguna', (tester) async {
      await seedProject(
        db,
        id: 'p2',
        name: 'Obra terminada',
        customerName: 'Ana Martínez',
        status: ProjectStatus.completed,
      );
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obra terminada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();

      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        find.text('Una obra terminada o cancelada no vuelve a cambiar de estado'),
        findsOne,
      );
    });
  });

  group('los dos temas', () {
    for (final (nombre, oscuro) in [('claro', false), ('oscuro', true)]) {
      testWidgets('$nombre: el alta se dibuja sin desbordes', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        tester.platformDispatcher.platformBrightnessTestValue = oscuro
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        try {
          await abrirAlta(tester);
          expect(find.byType(ProjectFormScreen), findsOne);
          expect(tester.takeException(), isNull);
        } finally {
          await disposeApp(tester);
        }
      });
    }

    testWithApp('la cartera tiene un solo naranja sólido', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      // "Ver todos" se queda en texto: si dos cosas son naranjas, ninguna es la
      // acción.
      expect(find.byType(FloatingActionButton), findsOne);
      expect(find.widgetWithText(FloatingActionButton, 'Nueva obra'), findsOne);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('el estado inicial', () {
    testWithApp('nace en proceso, para que aparezca en la cartera', (
      tester,
    ) async {
      await abrirAlta(tester);

      // Con `LEAD` la obra recién creada no aparecería en la cartera —que muestra
      // solo lo que está en proceso— y se leería como que no se guardó.
      expect(find.text('En proceso'), findsWidgets);
    });

    testWithApp('no se puede crear una obra ya cancelada', (tester) async {
      await abrirAlta(tester);

      await tester.tap(find.text('Estado (obligatorio)'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelado'), findsNothing);
      expect(find.text('Prospecto').hitTestable(), findsWidgets);
    });
  });

  group('la escalera de estados', () {
    test('desde prospecto no se salta a terminada', () {
      // Criterio del spec, verificado sobre la tabla que el selector consume.
      expect(
        nextStatusesFor(ProjectStatus.lead),
        isNot(contains(ProjectStatus.completed)),
      );
      expect(nextStatusesFor(ProjectStatus.lead), [
        ProjectStatus.estimated,
        ProjectStatus.cancelled,
      ]);
    });

    test('una obra terminada no ofrece cambios', () {
      expect(nextStatusesFor(ProjectStatus.completed), isEmpty);
    });
  });

  group('nada quemado', () {
    testWithApp('el formulario de un usuario en inglés sale en inglés', (
      tester,
    ) async {
      await pumpApp(tester, app(locale: AuthUserDtoLocale.en));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New project').first);
      await tester.pumpAndSettle();

      expect(find.text('Project name (required)'), findsOne);
      expect(find.text('Customer (required)'), findsOne);
      expect(find.text('Choose the customer first'), findsOne);
      expect(find.text('Nombre de la obra (obligatorio)'), findsNothing);
    });
  });
}
