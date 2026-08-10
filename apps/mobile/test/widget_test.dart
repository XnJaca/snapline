import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/core/theme/app_theme.dart';
import 'package:snapline/core/theme/theme_extensions.dart';
import 'package:snapline/core/theme/tokens.dart';

import 'support/fakes.dart';

late AppDatabase _db;

Widget _app(FakeSessionStorage storage) => testApp(
  db: _db,
  session: storage.session,
  sinSesion: storage.session == null,
);

void main() {
  setUp(() => _db = testDatabase());
  tearDown(() => _db.close());

  group('arranque', () {
    testWidgets('sin sesión guardada abre el login', (tester) async {
      await pumpApp(tester, _app(FakeSessionStorage()));
      await tester.pumpAndSettle();

      expect(find.text('Phone or email'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    // El criterio del spec: cerrar la app y reabrirla entra directo.
    testWidgets('con sesión guardada entra sin pedir credenciales', (
      tester,
    ) async {
      await pumpApp(tester, _app(FakeSessionStorage(buildSession())));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Proyectos'), findsOneWidget);
    });

    // Reabrir sin red conserva el idioma del último login, porque sale de la
    // sesión guardada y no de una llamada al servidor.
    testWidgets('aplica el idioma del usuario sin consultar al servidor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(FakeSessionStorage(buildSession(locale: AuthUserDtoLocale.es))),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Proyectos'), findsOneWidget);
    });

    testWidgets('un usuario en inglés ve la app en inglés', (tester) async {
      await tester.pumpWidget(
        _app(FakeSessionStorage(buildSession(locale: AuthUserDtoLocale.en))),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Projects'), findsOneWidget);
    });

    // Quién está adentro dejó de estar en la pantalla de inicio y pasó a la
    // pantalla de cuenta, que es de donde ahora se sale.
    testWidgets('la pantalla de cuenta muestra la persona y su empresa', (
      tester,
    ) async {
      await pumpApp(tester, _app(FakeSessionStorage(buildSession())));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('William Ferman'), findsOneWidget);
      expect(
        find.textContaining('Professional Construction LLC'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });
  });

  group('login', () {
    testWidgets('no llama al API con los campos vacíos', (tester) async {
      await pumpApp(tester, _app(FakeSessionStorage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your phone or email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('la contraseña se puede mostrar y ocultar', (tester) async {
      await pumpApp(tester, _app(FakeSessionStorage()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('tema', () {
    test('los dos temas exponen sus extensiones', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.extension<AppSpacing>(), isNotNull);
        expect(theme.extension<AppStatusColors>(), isNotNull);
      }
    });

    test('los dos temas usan Inter para la interfaz', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');
        expect(theme.textTheme.titleLarge?.fontFamily, isNot('BricolageGrotesque'));
      }
    });

    // La familia de marca no puede filtrarse al texto de interfaz: una display a
    // tamaño de lectura cansa y compite con el contenido.
    testWidgets('la familia de marca se usa solo en el wordmark', (
      tester,
    ) async {
      await pumpApp(tester, _app(FakeSessionStorage()));
      await tester.pumpAndSettle();

      final conMarca = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.fontFamily == Tokens.fontFamilyBrand);

      expect(conMarca, hasLength(1));
      expect(conMarca.single.data, 'Snapline');
    });

    test('el estilo del cronómetro lleva cifras tabulares', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(
          theme.textTheme.displaySmall?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    // La regla de 64dp vive en el tema y no en la disciplina de quien programa.
    test('la acción primaria mide 64dp de alto', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});
        expect(size?.height, 64.0);
      }
    });

    test('los estados tienen su par container', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final status = theme.extension<AppStatusColors>()!;
        expect(status.warningContainer, isNot(status.warning));
        expect(status.successContainer, isNot(status.success));
        expect(theme.colorScheme.errorContainer, isNot(theme.colorScheme.error));
      }
    });
  });
}
