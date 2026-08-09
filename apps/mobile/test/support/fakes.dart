import 'package:snapline/api/models/auth_membership_dto.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/session/session.dart';
import 'package:snapline/core/session/session_storage.dart';

/// Almacenamiento en memoria: el Keychain no existe en un test de unidad.
class FakeSessionStorage implements SessionStorage {
  FakeSessionStorage([this.session]);

  Session? session;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

Session buildSession({
  String name = 'William Ferman',
  AuthUserDtoLocale locale = AuthUserDtoLocale.es,
  String companyName = 'Professional Construction LLC',
  DateTime? expiresAt,
}) {
  return Session(
    accessToken: 'access',
    refreshToken: 'refresh',
    accessTokenExpiresAt:
        expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
    user: AuthUserDto(
      id: 'u1',
      name: name,
      locale: locale,
      email: 'w@example.com',
      phone: '+13015550142',
    ),
    membership: AuthMembershipDto(
      id: 'm1',
      companyId: 'c1',
      companyName: companyName,
      role: AuthMembershipDtoRole.owner,
    ),
    memberships: [
      AuthMembershipDto(
        id: 'm1',
        companyId: 'c1',
        companyName: companyName,
        role: AuthMembershipDtoRole.owner,
      ),
    ],
  );
}
