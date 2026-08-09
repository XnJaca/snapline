import 'package:snapline/api/models/auth_membership_dto.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/core/navigation/last_destination_store.dart';
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

/// Lo mismo para la preferencia de pestaña: `SharedPreferences` tampoco existe
/// en un test de unidad.
class FakeLastDestinationStore implements LastDestinationStore {
  FakeLastDestinationStore([this.destination]);

  AppDestination? destination;

  @override
  Future<AppDestination?> read() async => destination;

  @override
  Future<void> write(AppDestination value) async => destination = value;

  @override
  Future<void> clear() async => destination = null;
}

/// Los mismos que devuelve el API para cada rol. Ver `permissionsForRole` en
/// `apps/api/src/auth/permissions.ts`.
const permisosWorker = [
  'projects.read',
  'time.clock',
  'media.capture',
  'media.read',
  'profile.write',
];

const permisosForeman = [
  'projects.read',
  'crews.read',
  'time.clock',
  'time.read',
  'media.capture',
  'media.read',
  'profile.write',
];

const permisosAccountant = [
  'customers.read',
  'projects.read',
  'time.read',
  'catalog.read',
  'billing.read',
  'reports.read',
  'profile.write',
];

const permisosOwner = [
  'customers.read',
  'customers.write',
  'projects.read',
  'projects.write',
  'projects.publish',
  'crews.read',
  'crews.write',
  'time.clock',
  'time.read',
  'time.approve',
  'media.capture',
  'media.read',
  'media.visibility',
  'catalog.read',
  'catalog.write',
  'billing.read',
  'billing.write',
  'reports.read',
  'members.manage',
  'profile.write',
];

/// `ADMIN` tiene exactamente lo mismo que `OWNER` en `permissions.ts`.
const permisosPorRol = <AuthMembershipDtoRole, List<String>>{
  AuthMembershipDtoRole.owner: permisosOwner,
  AuthMembershipDtoRole.admin: permisosOwner,
  AuthMembershipDtoRole.foreman: permisosForeman,
  AuthMembershipDtoRole.worker: permisosWorker,
  AuthMembershipDtoRole.accountant: permisosAccountant,
};

Session buildSession({
  String name = 'William Ferman',
  AuthUserDtoLocale locale = AuthUserDtoLocale.es,
  String companyName = 'Professional Construction LLC',
  AuthMembershipDtoRole role = AuthMembershipDtoRole.owner,
  List<String>? permissions,
  DateTime? expiresAt,
}) {
  final membership = AuthMembershipDto(
    id: 'm1',
    companyId: 'c1',
    companyName: companyName,
    role: role,
    permissions: permissions ?? permisosPorRol[role] ?? permisosOwner,
  );

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
    membership: membership,
    memberships: [membership],
  );
}
