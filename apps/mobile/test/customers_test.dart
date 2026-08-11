import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/features/customers/customer_card.dart';
import 'package:snapline/features/customers/customer_form_screen.dart';
import 'package:snapline/features/customers/customers_screen.dart';

import 'support/fakes.dart';

/// SPEC-0006. Nada de acá toca la red: la lista sale de la base local, así que
/// con señal y sin señal se ve lo mismo.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = testDatabase();
    await seedCustomer(
      db,
      id: 'c1',
      displayName: 'Ana Martínez',
      companyName: 'Martinez Holdings',
      phone: '+13015550142',
      photoReleaseGrantedAt: DateTime(2026, 8, 1),
      siteLine1: '412 Ellsworth Dr',
    );
    await seedCustomer(
      db,
      id: 'c2',
      displayName: 'Bob Smith',
      companyName: 'Smith Roofing',
      phone: '+12405559988',
    );
    await seedCustomer(db, id: 'c3', displayName: 'Sin contacto');
  });

  tearDown(() => db.close());

  Widget app({AuthUserDtoLocale locale = AuthUserDtoLocale.es}) => testApp(
    db: db,
    session: buildSession(locale: locale),
    lastDestination: AppDestination.customers,
  );

  /// Los nombres de los clientes que la lista está mostrando.
  List<String> nombres(WidgetTester tester) => tester
      .widgetList<CustomerCard>(find.byType(CustomerCard))
      .map((card) => card.customer.displayName)
      .toList();

  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextField).first, texto);
    await tester.pumpAndSettle();
  }

  group('la lista', () {
    testWithApp('sale de la base local, sin consultar nada', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      expect(nombres(tester), ['Ana Martínez', 'Bob Smith', 'Sin contacto']);
    });

    testWithApp('un cliente creado en el teléfono aparece al instante', (
      tester,
    ) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      // Como si se hubiera dado de alta sin señal: PENDING y sin pasar por red.
      await seedCustomer(
        db,
        id: 'c4',
        displayName: 'Nuevo sin señal',
        syncStatus: SyncStatus.pending,
      );
      await tester.pumpAndSettle();

      expect(nombres(tester), contains('Nuevo sin señal'));
    });

    testWithApp('lo que no subió se muestra marcado', (tester) async {
      await seedCustomer(
        db,
        id: 'c5',
        displayName: 'Pendiente',
        syncStatus: SyncStatus.pending,
      );
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      // Guardar y que se vea como si ya estuviera en el servidor es lo que
      // después nadie entiende.
      expect(find.text('Guardado en el teléfono'), findsWidgets);
    });
  });

  group('la búsqueda', () {
    testWithApp('encuentra por nombre', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      await buscar(tester, 'martí');
      expect(nombres(tester), ['Ana Martínez']);
    });

    testWithApp('encuentra por empresa', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      await buscar(tester, 'roofing');
      expect(nombres(tester), ['Bob Smith']);
    });

    testWithApp('encuentra por teléfono', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      await buscar(tester, '5559988');
      expect(nombres(tester), ['Bob Smith']);
    });

    // Dos vacíos distintos: "todavía no cargó a nadie" y "buscó algo que no
    // está". El mismo mensaje para los dos manda a revisar el lugar equivocado.
    testWithApp('sin resultados dice que fue la búsqueda', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      await buscar(tester, 'zzzz');
      expect(nombres(tester), isEmpty);
      expect(find.text('Ningún cliente coincide con esa búsqueda'), findsOne);
    });

    testWithApp('la lista vacía dice qué hacer', (tester) async {
      await db.customStatement('DELETE FROM customers');
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Todavía no hay clientes. Agregue el primero para poder crear una obra.',
        ),
        findsOne,
      );
    });
  });

  group('el photo release', () {
    testWithApp('se ve en la lista sin entrar a la ficha', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      // Es lo que decide si esa obra se puede publicar (regla 17).
      expect(find.text('Permiso de fotos firmado'), findsOne);
      expect(find.text('Sin permiso de fotos'), findsWidgets);
    });

    testWithApp('la ficha no ofrece otorgarlo ni revocarlo', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Martínez'));
      await tester.pumpAndSettle();

      // Otorgarlo necesita el documento firmado y no se puede desde el móvil;
      // revocarlo despublica en cascada, que tampoco está implementado.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Permiso de fotos firmado'), findsOne);
    });
  });

  group('la ficha', () {
    Future<void> abrir(WidgetTester tester, String nombre) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
    }

    testWithApp('lista las propiedades del cliente', (tester) async {
      await abrir(tester, 'Ana Martínez');

      expect(find.text('Propiedades'), findsOne);
      expect(find.text('412 Ellsworth Dr, Silver Spring, MD'), findsOne);
    });

    testWithApp('sin propiedades dice qué falta y para qué', (tester) async {
      await abrir(tester, 'Bob Smith');

      expect(
        find.text(
          'Todavía no tiene propiedades. Agregue una para poder crear una obra acá.',
        ),
        findsOne,
      );
    });

    testWithApp('lista las obras del cliente', (tester) async {
      await seedProject(
        db,
        id: 'p1',
        name: 'Techo Martínez',
        customerName: 'no se usa',
      );
      // La obra sembrada cuelga de su propio cliente; se reasigna al de la
      // ficha para verificar que la sección filtra por cliente.
      await db.customStatement(
        'UPDATE projects SET customer_id = ? WHERE id = ?',
        ['c1', 'p1'],
      );

      await abrir(tester, 'Ana Martínez');
      expect(find.text('Obras'), findsOne);
      expect(find.text('Techo Martínez'), findsOne);
    });

    testWithApp('las obras de otro cliente no aparecen', (tester) async {
      await seedProject(
        db,
        id: 'p2',
        name: 'Obra de otro',
        customerName: 'Otro',
      );

      await abrir(tester, 'Ana Martínez');
      expect(find.text('Obra de otro'), findsNothing);
      expect(find.text('Este cliente todavía no tiene obras'), findsOne);
    });

    testWithApp('avisa cuando no va a poder entrar al portal', (tester) async {
      await abrir(tester, 'Sin contacto');

      // El dominio marca email y phone opcionales: se guarda igual, pero sin
      // uno de los dos no hay forma de invitarlo.
      expect(
        find.text(
          'Sin correo ni teléfono no se puede invitar a este cliente al portal.',
        ),
        findsOne,
      );
    });
  });

  group('el alta', () {
    testWithApp('la acción primaria abre el formulario', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerFormScreen), findsOne);
      // Lo obligatorio se dice en el label y con palabras, no con un asterisco.
      expect(find.text('Nombre (obligatorio)'), findsOne);
    });

    testWithApp('guardar sin nombre no crea nada', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Escriba un nombre'), findsOne);
      expect(find.byType(CustomerFormScreen), findsOne);
    });

    testWithApp('un cliente nuevo queda visible y marcado', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
        'Cliente de obra',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Reemplaza el formulario por la ficha, y el back vuelve a la lista.
      expect(find.byType(CustomerFormScreen), findsNothing);
      expect(find.text('Cliente de obra'), findsWidgets);
      expect(find.text('Guardado en el teléfono'), findsWidgets);
    });
  });

  group('el teléfono', () {
    Future<void> abrirAlta(WidgetTester tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
    }

    /// El payload que quedó encolado para el servidor.
    Future<Map<String, Object?>> payloadEncolado(AppDatabase db) async {
      final ops = await db.select(db.outboxOperations).get();
      return jsonDecode(ops.first.payload) as Map<String, Object?>;
    }

    testWithApp('el país se elige y arranca en el del design partner', (
      tester,
    ) async {
      await abrirAlta(tester);

      // Visible sin tocar nada: escondido detrás del label, quien no sabe que
      // se puede cambiar teclea su número con el prefijo de otro país.
      expect(find.byType(CountryButton), findsOne);
      // El prefijo lo escribe el paquete; si cambia de formato, cambia lo que ve
      // el usuario y este caso tiene que enterarse.
      expect(find.text('+ 1'), findsOne);
    });

    testWithApp('se guarda en E.164 y no como se tecleó', (tester) async {
      await abrirAlta(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
        'Con teléfono',
      );
      await tester.enterText(find.byType(PhoneFormField), '3015550142');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Un solo formato del lado del servidor, con el país que se eligió.
      expect((await payloadEncolado(db))['phone'], '+13015550142');
    });

    testWithApp('un número que no existe en ese país no deja guardar', (
      tester,
    ) async {
      await abrirAlta(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
        'Teléfono corto',
      );
      // Tres dígitos no son un teléfono en Estados Unidos. Sin el país no habría
      // forma de saberlo: lo único comprobable sería que hay algo escrito.
      await tester.enterText(find.byType(PhoneFormField), '301');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerFormScreen), findsOne);
      expect(await db.select(db.outboxOperations).get(), isEmpty);
    });

    testWithApp('vacío se guarda igual: el dominio lo marca opcional', (
      tester,
    ) async {
      await abrirAlta(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
        'Sin teléfono',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final payload = await payloadEncolado(db);
      expect(payload['displayName'], 'Sin teléfono');
      expect(payload.containsKey('phone'), isFalse);
    });
  });

  group('la ayuda', () {
    testWithApp('el aviso del portal explica qué es el portal', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      // El aviso solo da una noticia; "portal" no dice nada por sí solo.
      expect(
        find.text(
          'Sin correo ni teléfono no se puede invitar a este cliente al portal.',
        ),
        findsOne,
      );

      await tester.tap(find.byIcon(Icons.help_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('El portal del cliente'), findsOne);
      expect(find.textContaining('enlace privado'), findsOne);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('El portal del cliente'), findsNothing);
    });

    testWithApp('el aviso desaparece al escribir un contacto', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(PhoneFormField), '3015550142');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsNothing);
    });
  });

  group('la acción primaria', () {
    // Un botón sólido por pantalla. Si dos cosas son naranjas, ninguna es la
    // acción.
    testWithApp('es la única cosa naranja sólida de la lista', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      final naranjas = tester.widgetList<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(naranjas, hasLength(1));
      expect(find.widgetWithText(FloatingActionButton, 'Nuevo cliente'), findsOne);
    });
  });

  group('nada quemado', () {
    testWithApp('la pantalla de un usuario en inglés sale en inglés', (
      tester,
    ) async {
      await pumpApp(tester, app(locale: AuthUserDtoLocale.en));
      await tester.pumpAndSettle();

      expect(find.text('New customer'), findsOne);
      expect(find.text('Search by name, company or phone'), findsOne);
      expect(find.text('Photo release signed'), findsOne);
      expect(find.text('Nuevo cliente'), findsNothing);
    });

    testWithApp('y en español, en español', (tester) async {
      await pumpApp(tester, app());
      await tester.pumpAndSettle();

      expect(find.text('Nuevo cliente'), findsOne);
      expect(find.text('Buscar por nombre, empresa o teléfono'), findsOne);
      expect(find.text('New customer'), findsNothing);
    });

    testWithApp('los campos del formulario también', (tester) async {
      await pumpApp(tester, app(locale: AuthUserDtoLocale.en));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New customer'));
      await tester.pumpAndSettle();

      expect(find.text('Street address'), findsOne);
      expect(find.text('ZIP code'), findsOne);
      expect(find.text('How they found you'), findsOne);
    });
  });

  group('los dos temas', () {
    for (final (nombre, oscuro) in [('claro', false), ('oscuro', true)]) {
      testWidgets('$nombre: la lista se dibuja sin desbordes', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        tester.platformDispatcher.platformBrightnessTestValue = oscuro
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        try {
          await pumpApp(tester, app());
          await tester.pumpAndSettle();

          expect(find.byType(CustomersScreen), findsOne);
          // Un desborde en el árbol lo reporta el framework como excepción;
          // llegar acá sin ninguna es lo que se está verificando.
          expect(tester.takeException(), isNull);
        } finally {
          await disposeApp(tester);
        }
      });
    }
  });
}
