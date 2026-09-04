import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:sqlite3/sqlite3.dart';

/// Actualizar la app no puede vaciar la base local.
///
/// El caso concreto: un teléfono con la jornada entera sin sincronizar recibe la
/// versión nueva. **La bandeja de salida no se recrea nunca** — si se fuera con
/// una migración, el trabajo del día no llegaría jamás. Recrear otra tabla sí es
/// seguro, y la v5 lo hace para sacarle una columna a `customers`. Todo esto se
/// descubre abriendo la app, y ahí ya es tarde.
void main() {
  late Directory carpeta;
  late File archivo;

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('snapline-migracion');
    archivo = File('${carpeta.path}/snapline.sqlite');
  });

  tearDown(() => carpeta.deleteSync(recursive: true));

  /// La base como la dejó la versión anterior: esquema 1, sin los cuatro campos
  /// de cliente que trajo SPEC-0006.
  void crearEsquemaV1() {
    final db = sqlite3.open(archivo.path);
    db.execute('''
      CREATE TABLE customers (
        id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        display_name TEXT NOT NULL,
        company_name TEXT,
        email TEXT,
        phone TEXT,
        billing_address TEXT,
        photo_release_granted_at INTEGER,
        PRIMARY KEY (id)
      )
    ''');
    db.execute('''
      CREATE TABLE outbox_operations (
        client_id TEXT NOT NULL,
        type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        occurred_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        PRIMARY KEY (client_id)
      )
    ''');
    // `projects` nace con la app: ningún `onUpgrade` la crea. Estaba fuera de
    // este esquema simulado y por eso el salto no ejercitaba sus columnas.
    db.execute('''
      CREATE TABLE projects (
        id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        customer_id TEXT NOT NULL,
        site_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        service_type TEXT,
        status TEXT NOT NULL,
        client_visibility_mode TEXT NOT NULL,
        start_date INTEGER,
        target_end_date INTEGER,
        actual_end_date INTEGER,
        PRIMARY KEY (id)
      )
    ''');
    db.execute('PRAGMA user_version = 1');
    db.close();
  }

  test('la base de la versión anterior se abre y conserva sus filas', () async {
    crearEsquemaV1();

    final previa = sqlite3.open(archivo.path);
    previa.execute(
      'INSERT INTO customers (id, company_id, updated_at, sync_status, '
      'display_name, phone) VALUES (?, ?, ?, ?, ?, ?)',
      ['c1', 'co1', 1754700000, 2, 'Martínez', '+13015550142'],
    );
    // La jornada sin sincronizar: esto es lo que no se puede perder.
    previa.execute(
      'INSERT INTO outbox_operations (client_id, type, target_id, payload, '
      'occurred_at) VALUES (?, ?, ?, ?, ?)',
      ['op1', 'customer.create', 'c1', '{"displayName":"Martínez"}', 1754700000],
    );
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final clientes = await db.select(db.customers).get();
    expect(clientes, hasLength(1));
    expect(clientes.first.displayName, 'Martínez');
    expect(clientes.first.phone, '+13015550142');
    expect(clientes.first.syncStatus, SyncStatus.synced);

    final pendientes = await db.select(db.outboxOperations).get();
    expect(
      pendientes,
      hasLength(1),
      reason: 'la bandeja tiene que sobrevivir a la actualización',
    );
    expect(pendientes.first.type, 'customer.create');
  });

  test('las columnas nuevas quedan vacías y se pueden escribir', () async {
    crearEsquemaV1();

    final previa = sqlite3.open(archivo.path);
    previa.execute(
      'INSERT INTO customers (id, company_id, updated_at, display_name) '
      'VALUES (?, ?, ?, ?)',
      ['c1', 'co1', 1754700000, 'Martínez'],
    );
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    // Nulas para la fila que ya estaba: nadie las había llenado.
    final antes = await db.select(db.customers).getSingle();
    expect(antes.firstName, isNull);
    expect(antes.source, isNull);
    expect(antes.notes, isNull);

    await (db.update(db.customers)..where((c) => c.id.equals('c1'))).write(
      const CustomersCompanion(
        firstName: Value('Ana'),
        source: Value('REFERRAL'),
        notes: Value('Techo del vecino'),
      ),
    );

    final despues = await db.select(db.customers).getSingle();
    expect(despues.firstName, 'Ana');
    expect(despues.source, 'REFERRAL');
    expect(despues.notes, 'Techo del vecino');
  });

  test('subir de v2 a v3 crea las tablas del marcaje sin tocar la bandeja', () async {
    // La base como la dejó SPEC-0006: esquema 1 + las columnas de la v2, que es
    // lo que un teléfono actualizado hasta ayer tiene instalado.
    crearEsquemaV1();
    final previa = sqlite3.open(archivo.path);
    previa.execute('ALTER TABLE customers ADD COLUMN first_name TEXT');
    previa.execute('ALTER TABLE customers ADD COLUMN last_name TEXT');
    previa.execute('ALTER TABLE customers ADD COLUMN source TEXT');
    previa.execute('ALTER TABLE customers ADD COLUMN notes TEXT');
    previa.execute('PRAGMA user_version = 2');
    previa.execute(
      'INSERT INTO outbox_operations (client_id, type, target_id, payload, '
      'occurred_at) VALUES (?, ?, ?, ?, ?)',
      ['op1', 'site.update', 's1', '{"lat":9.9}', 1754700000],
    );
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    // Las tablas nuevas existen y se puede escribir el marcaje del día uno.
    await db.into(db.timeEntries).insert(
      TimeEntriesCompanion.insert(
        id: 't1',
        companyId: 'co1',
        updatedAt: DateTime.now(),
        projectId: 'p1',
        membershipId: 'm1',
        recordedByMembershipId: 'm1',
        clockInAt: DateTime.now(),
        method: 'SELF',
        status: 'PENDING',
      ),
    );
    expect(await db.select(db.timeEntries).get(), hasLength(1));
    expect(await db.select(db.crews).get(), isEmpty);
    expect(await db.select(db.people).get(), isEmpty);

    // Y la bandeja sigue entera, que es la promesa de toda migración.
    final pendientes = await db.select(db.outboxOperations).get();
    expect(pendientes, hasLength(1));
    expect(pendientes.first.type, 'site.update');

    // La v4 también entró en el mismo salto: las subidas pendientes existen.
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('subir a v5 borra el photo release y deja la bandeja intacta', () async {
    crearEsquemaV1();

    final previa = sqlite3.open(archivo.path);
    previa.execute(
      'INSERT INTO customers (id, company_id, updated_at, sync_status, '
      'display_name, phone, photo_release_granted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['c1', 'co1', 1754700000, 2, 'Martínez', '+13015550142', 1754700000],
    );
    previa.execute(
      'INSERT INTO outbox_operations (client_id, type, target_id, payload, '
      'occurred_at) VALUES (?, ?, ?, ?, ?)',
      ['op1', 'customer.create', 'c1', '{"displayName":"Martínez"}', 1754700000],
    );
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    // La fila sobrevive a que se recree la tabla, con lo que no era el release.
    final clientes = await db.select(db.customers).get();
    expect(clientes, hasLength(1));
    expect(clientes.first.displayName, 'Martínez');
    expect(clientes.first.phone, '+13015550142');
    expect(clientes.first.syncStatus, SyncStatus.synced);

    final pendientes = await db.select(db.outboxOperations).get();
    expect(
      pendientes,
      hasLength(1),
      reason: 'recrear customers no puede llevarse la bandeja',
    );
    await db.close();

    // La columna se fue de verdad, no quedó vacía.
    final despues = sqlite3.open(archivo.path);
    final columnas = despues
        .select('PRAGMA table_info(customers)')
        .map((fila) => fila['name'] as String);
    expect(columnas, isNot(contains('photo_release_granted_at')));
    despues.close();
  });

  /// El salto largo es el que rompe: `createTable` usa el esquema de hoy, así
  /// que una base vieja crea `time_entries` **ya con** las columnas de la v6 y
  /// volver a agregarlas falla por duplicado. Un teléfono que no se actualiza
  /// hace meses recorre exactamente este camino.
  test('de v1 a v6 de un salto, sin chocar con columnas que ya existen', () async {
    crearEsquemaV1();

    final previa = sqlite3.open(archivo.path);
    previa.execute(
      'INSERT INTO outbox_operations (client_id, type, target_id, payload, '
      'occurred_at) VALUES (?, ?, ?, ?, ?)',
      ['op1', 'media.register', 'a1', '{}', 1754700000],
    );
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    // La galería existe y se puede escribir.
    await db.into(db.mediaAssets).insert(
      MediaAssetsCompanion.insert(
        id: 'a1',
        companyId: 'co1',
        updatedAt: DateTime(2026, 8, 12),
        projectId: 'p1',
        kind: 'PHOTO',
        mime: 'image/jpeg',
        visibility: 'INTERNAL',
        uploadStatus: 'PENDING',
      ),
    );
    expect(await db.select(db.mediaAssets).get(), hasLength(1));

    // Y la bandeja llegó entera del otro lado del salto.
    expect(await db.select(db.outboxOperations).get(), hasLength(1));
  });

  /// El salto que de verdad va a hacer un teléfono con la app instalada: v5 es
  /// la versión anterior a este cambio. Es el único camino que ejercita el
  /// `addColumn` sobre `time_entries` — desde v1 la tabla ya nace con esas
  /// columnas y esa rama nunca corre.
  test('de v5 a v6 agrega las columnas sobre la tabla que ya existía', () async {
    crearEsquemaV1();
    final previa = sqlite3.open(archivo.path);
    // La base como la dejó la v5: columnas de la v2, tablas de la v3 y v4, y
    // `customers` ya sin el photo release.
    previa.execute('ALTER TABLE customers ADD COLUMN first_name TEXT');
    previa.execute('ALTER TABLE customers ADD COLUMN last_name TEXT');
    previa.execute('ALTER TABLE customers ADD COLUMN source TEXT');
    previa.execute('ALTER TABLE customers ADD COLUMN notes TEXT');
    previa.execute('''
      CREATE TABLE time_entries (
        id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        project_id TEXT NOT NULL,
        membership_id TEXT NOT NULL,
        recorded_by_membership_id TEXT NOT NULL,
        clock_in_at INTEGER NOT NULL,
        clock_out_at INTEGER,
        break_minutes INTEGER NOT NULL DEFAULT 0,
        method TEXT NOT NULL,
        status TEXT NOT NULL,
        flags TEXT NOT NULL DEFAULT '[]',
        PRIMARY KEY (id)
      )
    ''');
    previa.execute('''
      CREATE TABLE pending_uploads (
        asset_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        uploaded_at INTEGER,
        PRIMARY KEY (asset_id)
      )
    ''');
    previa.execute('CREATE TABLE crews (id TEXT NOT NULL PRIMARY KEY)');
    previa.execute('CREATE TABLE crew_members (id TEXT NOT NULL PRIMARY KEY)');
    previa.execute('CREATE TABLE people (membership_id TEXT NOT NULL PRIMARY KEY)');
    previa.execute(
      'INSERT INTO time_entries (id, company_id, updated_at, project_id, '
      'membership_id, recorded_by_membership_id, clock_in_at, method, status) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ['t1', 'co1', 1754700000, 'p1', 'm1', 'm1', 1754700000, 'SELF', 'PENDING'],
    );
    previa.execute(
      'INSERT INTO outbox_operations (client_id, type, target_id, payload, '
      'occurred_at) VALUES (?, ?, ?, ?, ?)',
      ['op1', 'media.register', 'a1', '{}', 1754700000],
    );
    previa.execute('PRAGMA user_version = 5');
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    // Las columnas nuevas existen y se pueden escribir sobre la fila que ya
    // estaba, que es lo que el salto desde v1 no llega a probar.
    await (db.update(db.timeEntries)..where((t) => t.id.equals('t1')))
        .write(const TimeEntriesCompanion(clockInPhotoId: Value('foto-1')));
    final marcaje = await db.select(db.timeEntries).getSingle();
    expect(marcaje.clockInPhotoId, 'foto-1');

    expect(await db.select(db.mediaAssets).get(), isEmpty);
    expect(await db.select(db.outboxOperations).get(), hasLength(1));
  });

  /// El salto que hace hoy un teléfono con la app instalada: v8 es la versión
  /// anterior a este cambio, y es el único camino que ejercita el `addColumn`
  /// sobre `projects` —desde v1 la tabla ya nace con la columna—.
  test('subir a v9 agrega el ancla sin tocar lo que ya estaba', () async {
    crearEsquemaV1();
    final previa = sqlite3.open(archivo.path);
    previa.execute(
      'INSERT INTO projects (id, company_id, updated_at, customer_id, site_id, '
      'name, status, client_visibility_mode) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      ['p1', 'co1', 1754700000, 'c1', 's1', 'Techo', 'IN_PROGRESS', 'STAGES'],
    );
    previa.execute('PRAGMA user_version = 8');
    previa.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    // La obra sobrevivió al salto y su ancla queda vacía hasta el próximo pull:
    // una obra sin fecha de creación simplemente no muestra ancla.
    final obra = await db.select(db.projects).getSingle();
    expect(obra.name, 'Techo');
    expect(obra.createdAt, null);

    await (db.update(db.projects)..where((p) => p.id.equals('p1')))
        .write(ProjectsCompanion(createdAt: Value(DateTime(2026, 8, 12))));
    expect((await db.select(db.projects).getSingle()).createdAt,
        DateTime(2026, 8, 12));
  });

  test('una base nueva arranca directamente en el esquema de ahora', () async {
    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    // Sin pasar por la migración: `onCreate` crea las tablas completas.
    await db.into(db.customers).insert(
      CustomersCompanion.insert(
        id: 'c1',
        companyId: 'co1',
        updatedAt: DateTime(2026, 8, 9),
        displayName: 'Martínez',
        firstName: const Value('Ana'),
      ),
    );

    final fila = await db.select(db.customers).getSingle();
    expect(fila.firstName, 'Ana');
  });
}
