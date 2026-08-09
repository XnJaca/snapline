import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/auth_membership_dto.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_result_dto.dart';
import 'package:snapline/api/models/auth_user_dto.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/session/session.dart';

import 'support/fakes.dart';

void main() {
  group('Session', () {
    test('sobrevive a serializar y volver a leer', () {
      final original = buildSession();
      final vuelta = Session.decode(original.encode());

      expect(vuelta.accessToken, original.accessToken);
      expect(vuelta.refreshToken, original.refreshToken);
      expect(vuelta.user.name, original.user.name);
      expect(vuelta.user.locale, AuthUserDtoLocale.es);
      expect(vuelta.membership.companyName, original.membership.companyName);
      expect(vuelta.memberships, hasLength(1));
      expect(
        vuelta.accessTokenExpiresAt.toIso8601String(),
        original.accessTokenExpiresAt.toIso8601String(),
      );
    });

    // expiresInSeconds es relativo al momento de emisión, y ese momento no se
    // puede reconstruir después de cerrar la app.
    test('convierte expiresInSeconds en un instante absoluto', () {
      final emitido = DateTime(2026, 8, 8, 10);
      final session = Session.fromAuthResult(
        AuthResultDto(
          accessToken: 'a',
          refreshToken: 'r',
          expiresInSeconds: 3600,
          user: AuthUserDto(
            id: 'u',
            name: 'n',
            locale: AuthUserDtoLocale.en,
            email: 'e',
            phone: 'p',
          ),
          membership: AuthMembershipDto(
            id: 'm',
            companyId: 'c',
            companyName: 'co',
            role: AuthMembershipDtoRole.worker,
            permissions: permisosWorker,
          ),
          memberships: const [],
        ),
        emitido,
      );

      expect(session.accessTokenExpiresAt, DateTime(2026, 8, 8, 11));
    });


    // Esto termina en logs y en reportes de error.
    test('no filtra tokens al convertirse en texto', () {
      final texto = buildSession().toString();
      expect(texto, isNot(contains('access')));
      expect(texto, isNot(contains('refresh')));
    });
  });

  group('FakeSessionStorage', () {
    test('guarda, lee y borra', () async {
      final storage = FakeSessionStorage();
      expect(await storage.read(), isNull);

      await storage.write(buildSession());
      expect(await storage.read(), isNotNull);

      await storage.clear();
      expect(await storage.read(), isNull);
    });
  });
}
