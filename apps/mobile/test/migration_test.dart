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
/// versión nueva. Si la migración recreara las tablas en vez de agregar columnas,
/// **la bandeja de salida se iría con ellas** y el trabajo del día no llegaría
/// nunca. Un `addColumn` es difícil de romper, pero esto se descubre abriendo la
/// app y ahí ya es tarde.
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
