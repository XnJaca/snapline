import 'package:drift/drift.dart';

/// El estado de sincronización de una fila.
///
/// `CONFLICT` **solo lo produce `time_entry`** y lo resuelve un humano: la
/// regla 12 no permite que unas horas se sobrescriban solas. Todo lo demás va
/// con última escritura gana y nunca llega a este estado.
enum SyncStatus { pending, syncing, synced, conflict }

/// Lo común a toda fila que sincroniza.
///
/// `deletedAt` en vez de borrar: un borrado duro no se puede propagar a un
/// dispositivo que estuvo sin señal (regla 20). Las consultas de la app filtran
/// por `deletedAt IS NULL`; la fila sigue ahí.
mixin SyncedTable on Table {
  /// UUIDv7 generado en el dispositivo. El registro nace con su id definitivo
  /// y no hay nada que reconciliar al sincronizar (regla 18).
  TextColumn get id => text()();

  TextColumn get companyId => text()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get syncStatus =>
      intEnum<SyncStatus>().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalCustomer')
class Customers extends Table with SyncedTable {
  TextColumn get displayName => text()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get companyName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();

  /// Uno de `CustomerSource` del contrato. Se guarda el texto y no el índice de
  /// un enum: un valor nuevo en el servidor llega y no rompe la base local.
  TextColumn get source => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// La dirección entera como JSON. Se guarda tal cual llega para no perder
  /// campos que el servidor agregue antes de que la app los conozca.
  TextColumn get billingAddress => text().nullable()();

  /// Lo único que habilita publicar (regla 17). Acá es solo para mostrarlo: la
  /// restricción de verdad vive en la base del servidor.
  DateTimeColumn get photoReleaseGrantedAt => dateTime().nullable()();
}

@DataClassName('LocalSite')
class Sites extends Table with SyncedTable {
  TextColumn get customerId => text()();
  TextColumn get address => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  IntColumn get geofenceRadiusM => integer().nullable()();
}

@DataClassName('LocalProject')
class Projects extends Table with SyncedTable {
  TextColumn get customerId => text()();
  TextColumn get siteId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get serviceType => text().nullable()();
  TextColumn get status => text()();
  TextColumn get clientVisibilityMode => text()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get targetEndDate => dateTime().nullable()();
  DateTimeColumn get actualEndDate => dateTime().nullable()();
}

/// La respuesta a *"no sé cuántos mandé a cada proyecto"*: lo planeado contra
/// lo que realmente marcó asistencia.
@DataClassName('LocalAssignment')
class ProjectAssignments extends Table with SyncedTable {
  TextColumn get projectId => text()();
  TextColumn get crewId => text().nullable()();
  TextColumn get membershipId => text().nullable()();
  DateTimeColumn get workDate => dateTime()();
  IntColumn get plannedHeadcount => integer().nullable()();
}

/// Las horas de la persona —o de su gente, si es foreman.
///
/// El agregado más delicado del sistema (regla 12): es la única tabla cuyo
/// `syncStatus` puede llegar a `CONFLICT`, y ahí se queda hasta que lo mire un
/// humano.
@DataClassName('LocalTimeEntry')
class TimeEntries extends Table with SyncedTable {
  TextColumn get projectId => text()();
  TextColumn get membershipId => text()();

  /// Quién marcó. No siempre es el dueño de la hora: el foreman marca por los
  /// suyos, y ese rastro es la defensa legal de la regla 12.
  TextColumn get recordedByMembershipId => text()();

  DateTimeColumn get clockInAt => dateTime()();
  DateTimeColumn get clockOutAt => dateTime().nullable()();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();

  /// `SELF`, `FOREMAN` o `ADMIN`, como texto: un valor nuevo del servidor llega
  /// sin romper la base local.
  TextColumn get method => text()();

  /// `PENDING` → `APPROVED` · `REJECTED`.
  TextColumn get status => text()();

  /// La lista de banderas como JSON. Informan, nunca bloquean (regla 9).
  TextColumn get flags => text().withDefault(const Constant('[]'))();
}

/// Las cuadrillas que la persona lidera o integra. Se cachean para que el
/// foreman vea a su gente sin señal.
@DataClassName('LocalCrew')
class Crews extends Table with SyncedTable {
  TextColumn get name => text()();
  TextColumn get foremanMembershipId => text().nullable()();
  TextColumn get color => text().nullable()();
}

/// La pertenencia lleva fechas: la gente rota, y un reporte de marzo refleja
/// quién estaba en marzo.
@DataClassName('LocalCrewMember')
class CrewMembers extends Table with SyncedTable {
  TextColumn get crewId => text()();
  TextColumn get membershipId => text()();
  DateTimeColumn get fromDate => dateTime()();
  DateTimeColumn get toDate => dateTime().nullable()();
}

/// La identidad mínima de cada membresía: un nombre donde iría un UUID.
///
/// Es una proyección del servidor, no un agregado: sin `SyncedTable` porque no
/// tiene ediciones locales que sincronizar, y su baja se aplica borrando la
/// fila — no hay dispositivo al que propagarle este borrado, la fuente es el
/// pull mismo.
@DataClassName('LocalPerson')
class People extends Table {
  TextColumn get membershipId => text()();
  TextColumn get name => text()();
  TextColumn get role => text()();

  @override
  Set<Column> get primaryKey => {membershipId};
}

/// Las fotos que esperan subir su binario.
///
/// El registro del asset viaja por la bandeja; el archivo pesa y sube aparte,
/// con reintento. Es una tabla y no memoria por la misma razón que la bandeja:
/// la foto de la jornada no puede perderse porque el sistema mató la app.
@DataClassName('PendingUpload')
class PendingUploads extends Table {
  /// El id del asset, generado en el dispositivo (regla 18).
  TextColumn get assetId => text()();

  TextColumn get filePath => text()();
  TextColumn get mime => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get uploadedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {assetId};
}

/// La bandeja de salida.
///
/// **Es una tabla y no una lista en memoria**: sobrevive a que el sistema mate
/// la app con la jornada entera sin sincronizar.
@DataClassName('OutboxOperation')
class OutboxOperations extends Table {
  /// La clave de idempotencia. Se reintenta siempre con la misma, así que el
  /// servidor responde `duplicate` en vez de duplicar (regla 19).
  TextColumn get clientId => text()();

  /// Uno de `SYNC_OPERATIONS` del contrato.
  TextColumn get type => text()();

  TextColumn get targetId => text()();

  TextColumn get payload => text()();

  /// Cuándo lo hizo la persona. Ordena el lote en el servidor: una salida no
  /// puede aplicarse antes que su entrada.
  DateTimeColumn get occurredAt => dateTime()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// El último error, para poder mostrar por qué algo no sube. Nulo mientras no
  /// haya fallado.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// Hasta dónde llegó el último pull. Lo da el servidor, **nunca el reloj del
/// dispositivo**: un teléfono con la hora corrida se perdería cambios.
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  TextColumn get id => text()();
  DateTimeColumn get serverTime => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
