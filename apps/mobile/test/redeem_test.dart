import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/core/network/api_failure.dart';
import 'package:snapline/api/export.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/features/auth/redeem_screen.dart';
import 'package:snapline/l10n/app_localizations.dart';

import 'support/fakes.dart';

DioException _respuesta(int status, {String? code}) {
  final options = RequestOptions(path: '/auth/invite/redeem');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Map<String, dynamic>>(
      requestOptions: options,
      statusCode: status,
      data: code == null ? null : {'code': code, 'message': 'no importa'},
    ),
  );
}

/// La pantalla necesita el tema de la app: los espaciados salen de ahí y no de
/// valores literales.
Widget _app(AppDatabase db, AuthUserDtoLocale locale) => testWidget(
  db: db,
  locale: locale,
  child: const RedeemScreen(),
);

void main() {
  /// Un código vencido y uno equivocado son los dos un 401. Lo que hay que hacer
  /// con cada uno es lo contrario —pedirle otro al jefe, o revisar los dígitos—,
  /// así que la app ramifica sobre el `code` estable y nunca sobre el status.
  group('el código del envelope llega hasta la pantalla', () {
    test('un 401 con INVITE_CODE_EXPIRED conserva su código', () {
      final failure = ApiFailure.from(
        _respuesta(401, code: ApiErrorCode.inviteExpired),
      );
      expect(failure.code, ApiErrorCode.inviteExpired);
      expect(failure.kind, ApiFailureKind.invalidCredentials);
    });

    test('un 429 por demasiados intentos también', () {
      final failure = ApiFailure.from(
        _respuesta(429, code: ApiErrorCode.inviteTooManyAttempts),
      );
      expect(failure.code, ApiErrorCode.inviteTooManyAttempts);
    });

    test('una respuesta sin envelope no inventa código', () {
      expect(ApiFailure.from(_respuesta(401)).code, isNull);
      expect(ApiFailure.from(_respuesta(500)).code, isNull);
    });

    test('sin conexión no hay código que leer', () {
      final failure = ApiFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/auth/invite/redeem'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(failure.isNoConnection, isTrue);
      expect(failure.code, isNull);
    });
  });

  group('la pantalla de canje', () {
    late AppDatabase db;

    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    testWidgets('el primer paso pide el código y no la contraseña', (
      tester,
    ) async {
      await tester.pumpWidget(_app(db, AuthUserDtoLocale.es));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RedeemScreen)),
      );

      // Escribir la contraseña y recién ahí enterarse de que el código no
      // servía es hacerle perder el trabajo a quien recién entra.
      expect(find.text(l10n.authRedeemPasswordLabel), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text(l10n.authRedeemContinue), findsOneWidget);
    });

    testWidgets('un código a medias no llega al servidor', (tester) async {
      await tester.pumpWidget(_app(db, AuthUserDtoLocale.es));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RedeemScreen)),
      );

      await tester.enterText(find.byType(TextFormField).at(0), '+13015550199');
      await tester.enterText(find.byType(TextFormField).at(1), '4829');
      // El formulario no entra en la ventana del test: sin esto el toque cae
      // fuera del botón y el test falla por el viewport, no por la validación.
      await tester.ensureVisible(find.text(l10n.authRedeemContinue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.authRedeemContinue));
      await tester.pumpAndSettle();

      expect(find.text(l10n.authRedeemCodeLength), findsOneWidget);
    });

    testWidgets('el campo del código solo acepta dígitos', (tester) async {
      await tester.pumpWidget(_app(db, AuthUserDtoLocale.es));
      await tester.pumpAndSettle();

      // Se dicta en voz alta y se escribe con guantes: una letra colada haría
      // fallar el canje sin que se vea por qué.
      await tester.enterText(find.byType(TextFormField).at(1), '48a29b15');
      await tester.pumpAndSettle();

      final campo = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(campo.controller?.text, '482915');
    });

    testWidgets('nada quemado: sale en inglés con la app en inglés', (
      tester,
    ) async {
      await tester.pumpWidget(_app(db, AuthUserDtoLocale.en));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RedeemScreen)),
      );
      expect(l10n.authRedeemTitle, 'Access code');
      expect(find.text(l10n.authRedeemTitle), findsOneWidget);
      expect(find.text(l10n.authRedeemContinue), findsOneWidget);
    });
  });
}
