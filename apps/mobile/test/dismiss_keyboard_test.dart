import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/data/local/app_database.dart';

import 'support/fakes.dart';

/// Tocar fuera de un campo cierra el teclado.
///
/// El teclado tapa media pantalla en un teléfono: sin esto, quien terminó de
/// escribir no puede ver el resto del formulario ni el botón de guardar. Va en
/// `MaterialApp.builder`, así que estos casos verifican de paso que valga en una
/// pantalla y en una hoja modal, que viven en scopes distintos del árbol.
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
  });

  tearDown(() => db.close());

  Widget app() => testApp(
    db: db,
    session: buildSession(),
    lastDestination: AppDestination.customers,
  );

  /// Hay un **campo de texto** con el foco, que es lo que mantiene el teclado
  /// arriba.
  ///
  /// No se mide con `primaryFocus`: después de un `unfocus()` el foco no queda en
  /// null, pasa al scope padre, que también reporta `hasFocus`. Con eso el test
  /// pasaba en verde con el teclado abierto.
  bool campoConFoco(WidgetTester tester) => tester
      .widgetList<EditableText>(find.byType(EditableText))
      .any((campo) => campo.focusNode.hasFocus);

  testWithApp('tocar el fondo de una pantalla saca el foco del campo', (
    tester,
  ) async {
    await pumpApp(tester, app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(campoConFoco(tester), isTrue, reason: 'el buscador tendría que tener el foco');

    // El área de la lista, lejos de cualquier control.
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(campoConFoco(tester), isFalse);
  });

  testWithApp('también dentro de una hoja modal', (tester) async {
    await pumpApp(tester, app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre (obligatorio)').first,
      'Con el teclado arriba',
    );
    await tester.pumpAndSettle();
    expect(campoConFoco(tester), isTrue);

    // El título de la hoja: dentro de ella y sin ser un control.
    await tester.tap(find.text('Nuevo cliente').last);
    await tester.pumpAndSettle();

    expect(campoConFoco(tester), isFalse);
  });

  testWithApp('pasar de un campo a otro no cierra el teclado', (tester) async {
    await pumpApp(tester, app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.tap(campos.first);
    await tester.pumpAndSettle();
    expect(campoConFoco(tester), isTrue);

    // Es la razón de que el hit test excluya los campos: cerrar y volver a abrir
    // el teclado al saltar de campo lo hace parpadear en la cara del usuario.
    await tester.tap(campos.at(1));
    await tester.pumpAndSettle();

    expect(campoConFoco(tester), isTrue);
  });

  testWithApp('no le roba el toque a un botón', (tester) async {
    await pumpApp(tester, app());
    await tester.pumpAndSettle();

    // Con `translucent` el padre recibe los toques del espacio vacío, pero un
    // hijo que gana la arena de gestos sigue funcionando: si esto se rompiera, la
    // app entera dejaría de responder a los botones.
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre (obligatorio)'), findsWidgets);
  });

  testWithApp('no rompe el scroll de una lista', (tester) async {
    for (var i = 0; i < 20; i++) {
      await seedCustomer(db, id: 'c$i', displayName: 'Cliente $i');
    }
    await pumpApp(tester, app());
    await tester.pumpAndSettle();

    // `onTap` no compite con un drag, pero conviene tenerlo fijado: un
    // `GestureDetector` global mal puesto mata el scroll de toda la app.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOne);
  });
}
