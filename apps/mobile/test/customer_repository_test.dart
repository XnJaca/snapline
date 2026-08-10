import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/address_dto.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/local/tables.dart';
import 'package:snapline/data/repositories/customer_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// El alta y la corrección de clientes sin señal: se escribe local, se encola, y
/// el id con el que nace es el definitivo.
void main() {
  late AppDatabase db;
  late Outbox outbox;
  late CustomerRepository repo;

  const direccion = AddressDto(
    line1: '412 Ellsworth Dr',
    city: 'Silver Spring',
    state: 'MD',
    postalCode: '20910',
  );

  setUp(() {
    db = testDatabase();
    outbox = Outbox(db, const Uuid());
    repo = CustomerRepository(db, outbox, const Uuid());
  });

  tearDown(() => db.close());

  group('alta de cliente', () {
    test('queda visible al instante y marcada como pendiente', () async {
      final id = await repo.create(
        const CustomerInput(displayName: 'Martínez', phone: '+13015550142'),
      );

      final lista = await repo.watchAll().first;
      expect(lista, hasLength(1));
      expect(lista.first.id, id);
      expect(lista.first.displayName, 'Martínez');
      // Guardar y que se vea como si estuviera sincronizado es lo que después
      // nadie entiende.
      expect(lista.first.pending, isTrue);
    });

    test('el id del dispositivo es el que va al servidor', () async {
      final id = await repo.create(const CustomerInput(displayName: 'Martínez'));

      final pendientes = await outbox.pending();
      expect(pendientes, hasLength(1));
      expect(pendientes.first.type, SyncOp.customerCreate);
      // Regla 18: no hay id temporal que reconciliar.
      expect(pendientes.first.targetId, id);
    });

    test('el payload no manda el photo release', () async {
      await repo.create(const CustomerInput(displayName: 'Martínez'));

      final payload =
          jsonDecode((await outbox.pending()).first.payload)
              as Map<String, Object?>;
      // Regla 17: otorgarlo necesita el documento firmado y no se puede hacer
      // desde el móvil. Si la clave viajara, el servidor la aceptaría.
      expect(payload.containsKey('photoReleaseGrantedAt'), isFalse);
      expect(payload.containsKey('photoReleaseDocumentId'), isFalse);
    });

    test('los campos vacíos no viajan', () async {
      await repo.create(
        const CustomerInput(displayName: 'Martínez', email: '', phone: ''),
      );

      final payload =
          jsonDecode((await outbox.pending()).first.payload)
              as Map<String, Object?>;
      // Un `""` contra el `@IsEmail()` del API es un 400, y significa lo mismo
      // que no mandarlo.
      expect(payload.keys, ['displayName']);
    });

    test('se puede guardar sin correo ni teléfono', () async {
      final id = await repo.create(const CustomerInput(displayName: 'Martínez'));

      final lista = await repo.watchAll().first;
      expect(lista.first.id, id);
      // El dominio los marca opcionales; lo que no va a poder es entrar al
      // portal, y eso lo avisa la pantalla.
      expect(lista.first.canBeInvited, isFalse);
    });
  });

  group('búsqueda', () {
    setUp(() async {
      await seedCustomer(
        db,
        id: 'c1',
        displayName: 'Ana Martínez',
        companyName: 'Martinez Holdings',
        phone: '+13015550142',
      );
      await seedCustomer(
        db,
        id: 'c2',
        displayName: 'Bob Smith',
        companyName: 'Smith Roofing',
        phone: '+12405559988',
      );
    });

    test('encuentra por nombre', () async {
      final lista = await repo.watchAll(query: 'martí').first;
      expect(lista.map((c) => c.id), ['c1']);
    });

    test('encuentra por empresa', () async {
      final lista = await repo.watchAll(query: 'roofing').first;
      expect(lista.map((c) => c.id), ['c2']);
    });

    test('encuentra por teléfono', () async {
      final lista = await repo.watchAll(query: '5559988').first;
      expect(lista.map((c) => c.id), ['c2']);
    });

    test('sin coincidencias devuelve vacío, no todo', () async {
      final lista = await repo.watchAll(query: 'zzz').first;
      expect(lista, isEmpty);
    });

    test('un borrado no se lista', () async {
      await db.customStatement('UPDATE customers SET deleted_at = ? WHERE id = ?', [
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'c1',
      ]);

      // Regla 20: la fila sigue en la base para poder propagarse.
      final lista = await repo.watchAll().first;
      expect(lista.map((c) => c.id), ['c2']);
    });
  });

  group('propiedades', () {
    test('una propiedad nueva queda colgada de su cliente', () async {
      final customerId = await repo.create(
        const CustomerInput(displayName: 'Martínez'),
      );
      final siteId = await repo.addSite(customerId, direccion);

      final sitios = await repo.watchSites(customerId).first;
      expect(sitios.map((s) => s.id), [siteId]);
      expect(sitios.first.oneLine, '412 Ellsworth Dr, Silver Spring, MD');
      expect(sitios.first.pending, isTrue);
    });

    test('de qué cliente cuelga viaja en el payload', () async {
      final customerId = await repo.create(
        const CustomerInput(displayName: 'Martínez'),
      );
      final siteId = await repo.addSite(customerId, direccion);

      final op = (await outbox.pending()).last;
      expect(op.type, SyncOp.siteCreate);
      // `targetId` es el id de la propiedad; una propiedad no existe suelta.
      expect(op.targetId, siteId);
      final payload = jsonDecode(op.payload) as Map<String, Object?>;
      expect(payload['customerId'], customerId);
    });

    test('las propiedades de otro cliente no se mezclan', () async {
      final uno = await repo.create(const CustomerInput(displayName: 'Uno'));
      final dos = await repo.create(const CustomerInput(displayName: 'Dos'));
      await repo.addSite(uno, direccion);

      expect(await repo.watchSites(dos).first, isEmpty);
    });

    test('corregir la dirección encola site.update', () async {
      await seedCustomer(db, id: 'c1', displayName: 'Martínez', siteLine1: 'Vieja');

      await repo.updateSite(
        's-c1',
        const AddressDto(
          line1: '9800 Georgia Ave',
          city: 'Silver Spring',
          state: 'MD',
          postalCode: '20902',
        ),
      );

      final sitios = await repo.watchSites('c1').first;
      expect(sitios.first.address?.line1, '9800 Georgia Ave');
      expect(sitios.first.pending, isTrue);

      final op = (await outbox.pending()).single;
      expect(op.type, SyncOp.siteUpdate);
      expect(op.targetId, 's-c1');
      final payload = jsonDecode(op.payload) as Map<String, Object?>;
      final enviada = payload['address'] as Map<String, Object?>;
      expect(enviada['line1'], '9800 Georgia Ave');
      // `lat`, `lng` y el radio son de asistencia: no se tocan desde acá.
      expect(payload.keys, ['address']);
    });
  });

  group('corrección de cliente', () {
    test('se ve al instante y encola una sola operación', () async {
      await seedCustomer(db, id: 'c1', displayName: 'Martinez', phone: '301');

      await repo.update(
        'c1',
        const CustomerInput(
          displayName: 'Ana Martínez',
          phone: '+13015550142',
        ),
      );

      final lista = await repo.watchAll().first;
      expect(lista.first.displayName, 'Ana Martínez');
      expect(lista.first.phone, '+13015550142');
      expect(lista.first.pending, isTrue);
      expect(await outbox.pending(), hasLength(1));
    });

    test('no toca el photo release que ya estaba', () async {
      final otorgado = DateTime(2026, 8, 1);
      await seedCustomer(
        db,
        id: 'c1',
        displayName: 'Martínez',
        photoReleaseGrantedAt: otorgado,
      );

      await repo.update('c1', const CustomerInput(displayName: 'Corregido'));

      final ficha = await repo.watchOne('c1').first;
      // Es de solo lectura en el móvil: una corrección de nombre no puede
      // revocarlo, porque revocar despublica en cascada.
      expect(ficha!.photoReleaseGrantedAt, otorgado);
    });

    test('la dirección de facturación va y vuelve entera', () async {
      await seedCustomer(db, id: 'c1', displayName: 'Martínez');

      await repo.update(
        'c1',
        const CustomerInput(
          displayName: 'Martínez',
          billingAddress: AddressDto(
            line1: '412 Ellsworth Dr',
            line2: 'Apt 3',
            city: 'Silver Spring',
            state: 'MD',
            postalCode: '20910',
          ),
        ),
      );

      final ficha = await repo.watchOne('c1').first;
      expect(ficha!.billingAddress?.line2, 'Apt 3');
      expect(ficha.billingAddress?.postalCode, '20910');
      expect(ficha.billingAddress?.country, 'US');
    });
  });

  // El caso que importa del spec: si esto no funciona, el prototipo no sirve.
  group('cliente, propiedad y obra sin señal', () {
    test('las tres salen de la bandeja en el orden en que se crearon', () async {
      final customerId = await repo.create(
        const CustomerInput(displayName: 'Martínez'),
      );
      final siteId = await repo.addSite(customerId, direccion);
      await outbox.enqueue(
        type: SyncOp.projectCreate,
        targetId: 'p1',
        payload: {'customerId': customerId, 'siteId': siteId, 'name': 'Techo'},
      );

      final pendientes = await outbox.pending();
      expect(
        pendientes.map((o) => o.type),
        [SyncOp.customerCreate, SyncOp.siteCreate, SyncOp.projectCreate],
      );
    });

    test('con el mismo instante el orden sigue siendo el correcto', () async {
      // Tres toques rápidos caen en el mismo milisegundo. Sin desempate, la
      // propiedad puede salir antes que su cliente y el servidor la rechaza.
      final momento = DateTime(2026, 8, 9, 14);
      final customerId = await repo.create(
        const CustomerInput(displayName: 'Martínez'),
        occurredAt: momento,
      );
      final siteId = await repo.addSite(
        customerId,
        direccion,
        occurredAt: momento,
      );
      await outbox.enqueue(
        type: SyncOp.projectCreate,
        targetId: 'p1',
        payload: {'customerId': customerId, 'siteId': siteId},
        occurredAt: momento,
      );

      final pendientes = await outbox.pending();
      expect(
        pendientes.map((o) => o.type),
        [SyncOp.customerCreate, SyncOp.siteCreate, SyncOp.projectCreate],
      );
    });

    // La columna guarda segundos enteros, no milisegundos: el desempate avanza de
    // a un segundo. Con paso de milisegundo el valor persistido no cambiaba y el
    // bucle daba mil vueltas por colisión — casi un segundo de espera en el
    // camino más común del spec.
    test('el desempate avanza en segundos, que es lo que la base guarda', () async {
      final momento = DateTime(2026, 8, 9, 14);
      final customerId = await repo.create(
        const CustomerInput(displayName: 'Martínez'),
        occurredAt: momento,
      );
      await repo.addSite(customerId, direccion, occurredAt: momento);

      final crudo = await db
          .customSelect(
            'SELECT occurred_at FROM outbox_operations ORDER BY occurred_at',
          )
          .get();
      final segundos = crudo.map((f) => f.data['occurred_at'] as int).toList();

      expect(segundos, hasLength(2));
      expect(
        segundos[1] - segundos[0],
        1,
        reason: 'un segundo de diferencia, no cero ni mil pasos intermedios',
      );
    });

    test('el cliente recién creado ya sirve para colgarle una propiedad', () async {
      final customerId = await repo.create(
        const CustomerInput(displayName: 'Martínez'),
      );

      // Sin haber sincronizado: el id ya es el definitivo.
      final sitios = await repo.watchSites(customerId).first;
      expect(sitios, isEmpty);
      await repo.addSite(customerId, direccion);
      expect(await repo.watchSites(customerId).first, hasLength(1));
    });
  });

  group('la fila local', () {
    test('nace PENDING y no SYNCED', () async {
      final id = await repo.create(const CustomerInput(displayName: 'Martínez'));

      final fila = await (db.select(
        db.customers,
      )..where((c) => c.id.equals(id))).getSingle();
      expect(fila.syncStatus, SyncStatus.pending);
    });

    test('corregir vuelve a PENDING una fila ya sincronizada', () async {
      await seedCustomer(db, id: 'c1', displayName: 'Martínez');

      await repo.update('c1', const CustomerInput(displayName: 'Corregido'));

      final fila = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c1'))).getSingle();
      expect(fila.syncStatus, SyncStatus.pending);
    });
  });
}
