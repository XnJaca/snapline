import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapline/core/navigation/last_destination_store.dart';
import 'package:snapline/core/session/session_storage.dart';
import 'package:snapline/core/theme/locale_store.dart';
import 'package:snapline/main.dart';
import 'package:snapline/api/models/project_status.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/sync/sync_controller.dart';

import 'package:snapline/api/models/auth_membership_dto.dart';
import 'package:snapline/api/models/auth_membership_dto_role.dart';
import 'package:snapline/api/models/auth_user_dto.dart';
import 'package:snapline/api/models/auth_user_dto_locale.dart';
import 'package:snapline/core/navigation/app_destination.dart';
import 'package:snapline/core/session/session.dart';

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

/// El idioma elegido, en memoria.
class FakeLocaleStore implements LocaleStore {
  FakeLocaleStore([this.locale]);

  Locale? locale;

  @override
  Future<Locale?> read() async => locale;

  @override
  Future<void> write(Locale? value) async => locale = value;
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


/// Base en memoria: cada test arranca con la suya, vacía.
AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());

/// No toca la red. La sincronización de verdad se prueba contra el API en
/// `integration_test/`; acá lo que importa es que la UI lea de local.
class FakeSyncController extends SyncController {
  @override
  Future<bool> build() async => true;
}

/// La app montada para un test: base en memoria, sin red, con la sesión que se
/// le pase. Evita repetir seis overrides en cada caso.
Widget testApp({
  required AppDatabase db,
  Session? session,
  bool sinSesion = false,
  AppDestination? lastDestination,
  FakeLastDestinationStore? lastDestinationStore,
  LocaleStore? localeStore,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      syncControllerProvider.overrideWith(FakeSyncController.new),
      sessionStorageProvider.overrideWithValue(
        FakeSessionStorage(sinSesion ? null : (session ?? buildSession())),
      ),
      lastDestinationStoreProvider.overrideWithValue(
        lastDestinationStore ?? FakeLastDestinationStore(lastDestination),
      ),
      localeStoreProvider.overrideWithValue(localeStore ?? FakeLocaleStore()),
    ],
    child: const SnaplineApp(),
  );
}

/// Siembra una obra con su cliente y su sitio, como si hubiera bajado del
/// servidor: todo `SYNCED`, que es como entra lo que ya está allá.
Future<void> seedProject(
  AppDatabase db, {
  required String id,
  required String name,
  required String customerName,
  ProjectStatus status = ProjectStatus.inProgress,
  String line1 = '412 Ellsworth Dr',
  String city = 'Silver Spring',
  SyncStatus syncStatus = SyncStatus.synced,
}) async {
  final ahora = DateTime.now();
  final customerId = 'c-$id';
  final siteId = 's-$id';

  await db.into(db.customers).insertOnConflictUpdate(
    CustomersCompanion.insert(
      id: customerId,
      companyId: 'c1',
      updatedAt: ahora,
      displayName: customerName,
      syncStatus: const Value(SyncStatus.synced),
    ),
  );
  await db.into(db.sites).insertOnConflictUpdate(
    SitesCompanion.insert(
      id: siteId,
      companyId: 'c1',
      updatedAt: ahora,
      customerId: customerId,
      address: jsonEncode({'line1': line1, 'city': city, 'state': 'MD'}),
      syncStatus: const Value(SyncStatus.synced),
    ),
  );
  await db.into(db.projects).insertOnConflictUpdate(
    ProjectsCompanion.insert(
      id: id,
      companyId: 'c1',
      updatedAt: ahora,
      customerId: customerId,
      siteId: siteId,
      name: name,
      status: status.json!,
      clientVisibilityMode: 'STAGES',
      syncStatus: Value(syncStatus),
    ),
  );
}


/// Monta la app y deja programado su desmontaje **dentro** del test.
///
/// Drift crea un timer al cancelar sus streams. Si el árbol se desmonta recién
/// cuando el caso terminó, ese timer queda pendiente y el framework lo reporta
/// como error aunque no haya nada roto.
Future<void> pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
