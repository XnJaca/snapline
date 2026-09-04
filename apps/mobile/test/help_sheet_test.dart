import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/widgets/help_sheet.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/l10n/app_localizations.dart';

import 'support/fakes.dart';

/// La hoja de ayuda.
///
/// Explica algo que la interfaz nombra pero no puede explicar al lado de un
/// campo. Lo que se verifica acá es que se pueda salir de ella —era texto plano
/// y no se leía como un botón— y que su copy hable de lo que el portal informa,
/// no de lo que el cliente no llega a saber.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> abrir(
    WidgetTester tester, {
    AuthUserDtoLocale locale = AuthUserDtoLocale.es,
    ThemeMode theme = ThemeMode.light,
  }) async {
    await tester.pumpWidget(testWidget(
      db: db,
      locale: locale,
      themeMode: theme,
      session: buildSession(locale: locale),
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return TextButton(
            onPressed: () => showHelpSheet(
              context,
              title: l10n.projectVisibilityStagesHelpTitle,
              body: l10n.projectVisibilityStagesHelpBody,
            ),
            child: const Text('abrir'),
          );
        },
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWithApp('la salida se ve como un botón, no como texto suelto', (
    tester,
  ) async {
    // Tonal y no naranja: la hoja no pide una decisión, así que cerrarla no es
    // la acción primaria de la app. Pero es la única salida que ofrece.
    await abrir(tester);

    final boton = find.widgetWithText(FilledButton, 'Entendido');
    expect(boton, findsOne);

    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.text('Entendido'), findsNothing);
  });

  testWithApp('el copy dice qué informa el portal, no qué se le esconde', (
    tester,
  ) async {
    // Decía «así el cliente sabe cómo va sin enterarse de que la obra estuvo
    // pausada tres días». Le explicaba a William cómo ocultarle algo a su
    // cliente, y eso no es lo que hace el modo por etapas.
    await abrir(tester);

    final hoja = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join(' ');

    expect(hoja, isNot(contains('sin enterarse')));
    expect(hoja, contains('El portal informa el avance de la obra'));
    // Y dice dónde se cambia, que es la pregunta que deja abierta.
    expect(hoja, contains('ficha de la obra'));
  });

  testWithApp('nada quemado: en inglés la ayuda sale en inglés', (tester) async {
    await abrir(tester, locale: AuthUserDtoLocale.en);

    expect(find.widgetWithText(FilledButton, 'Got it'), findsOne);
    expect(find.textContaining('private link'), findsOne);
  });

  for (final (nombre, theme) in [
    ('claro', ThemeMode.light),
    ('oscuro', ThemeMode.dark),
  ]) {
    testWithApp('$nombre: la hoja se dibuja sin desbordes', (tester) async {
      await abrir(tester, theme: theme);
      expect(tester.takeException(), isNull);
    });
  }
}
