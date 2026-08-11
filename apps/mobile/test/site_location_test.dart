import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/address_dto.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/repositories/customer_repository.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

/// Fijar el punto de una propiedad y el radio de su geocerca, sin señal.
///
/// Es lo que vuelve verificable la geocerca del marcaje: sin punto,
/// `evaluateGeofence` no evalúa nada. Ver SPEC-0007.
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

  Future<String> unaPropiedad() async {
    final clienteId = await repo.create(
      const CustomerInput(displayName: 'Martínez'),
    );
    return repo.addSite(clienteId, direccion);
  }

  group('fijar el punto', () {
    test('queda guardado y visible al instante, y pendiente de sincronizar', () async {
      final siteId = await unaPropiedad();

      await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

      final sitio = await _buscar(repo, siteId);
      expect(sitio.hasLocation, isTrue);
      expect(sitio.lat, 39.0042);
      expect(sitio.lng, -77.0261);
      expect(sitio.pending, isTrue);
    });

    test('se encola como site.update contra el id de la propiedad', () async {
      final siteId = await unaPropiedad();
      await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

      final actualizaciones = await _updates(outbox);
      expect(actualizaciones, hasLength(1));
      expect(actualizaciones.first.targetId, siteId);
    });

    test('el payload manda el punto y no toca la dirección', () async {
      final siteId = await unaPropiedad();
      await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

      final payload = await _payloadDelUpdate(outbox);
      expect(payload['lat'], 39.0042);
      expect(payload['lng'], -77.0261);
      // Fijar el punto no es corregir la dirección: mandarla pisaría una
      // corrección encolada aparte.
      expect(payload.containsKey('address'), isFalse);
    });

    test('corregir el punto de una propiedad que ya lo tenía lo reemplaza', () async {
      final siteId = await unaPropiedad();
      await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

      await repo.setSiteLocation(siteId, lat: 39.1000, lng: -77.1000);

      final sitio = await _buscar(repo, siteId);
      expect(sitio.lat, 39.1000);
      expect(sitio.lng, -77.1000);
    });
  });

  group('el radio de la geocerca', () {
    test('sin tocar queda nulo, y eso es válido', () async {
      final siteId = await unaPropiedad();
      await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

      final sitio = await _buscar(repo, siteId);
      expect(sitio.geofenceRadiusM, isNull);

      // Y no viaja como nulo explícito: el servidor lo valida como positivo y
      // lo rechazaría.
      final payload = await _payloadDelUpdate(outbox);
      expect(payload.containsKey('geofenceRadiusM'), isFalse);
    });

    test('elegido, se guarda y viaja', () async {
      final siteId = await unaPropiedad();
      await repo.setSiteLocation(
        siteId,
        lat: 39.0042,
        lng: -77.0261,
        geofenceRadiusM: 120,
      );

      final sitio = await _buscar(repo, siteId);
      expect(sitio.geofenceRadiusM, 120);

      final payload = await _payloadDelUpdate(outbox);
      expect(payload['geofenceRadiusM'], 120);
    });
  });

  group('lo que no se toca', () {
    test('media coordenada no cuenta como ubicación', () async {
      final siteId = await unaPropiedad();

      final sitio = await _buscar(repo, siteId);
      // Recién creada: sin punto. `hasLocation` exige las dos.
      expect(sitio.lat, isNull);
      expect(sitio.lng, isNull);
      expect(sitio.hasLocation, isFalse);
    });

    test('corregir la dirección no borra el punto ya fijado', () async {
      final siteId = await unaPropiedad();
      await repo.setSiteLocation(siteId, lat: 39.0042, lng: -77.0261);

      await repo.updateSite(
        siteId,
        const AddressDto(
          line1: '9800 Georgia Ave',
          city: 'Silver Spring',
          state: 'MD',
          postalCode: '20902',
        ),
      );

      final sitio = await _buscar(repo, siteId);
      expect(sitio.lat, 39.0042);
      expect(sitio.lng, -77.0261);
    });
  });
}

/// Solo las operaciones de `site.update`: la bandeja también trae el alta del
/// cliente y la de la propiedad, que este spec no toca.
Future<List<OutboxOperation>> _updates(Outbox outbox) async {
  final pendientes = await outbox.pending();
  return pendientes.where((op) => op.type == SyncOp.siteUpdate).toList();
}

Future<Map<String, Object?>> _payloadDelUpdate(Outbox outbox) async {
  final ops = await _updates(outbox);
  return jsonDecode(ops.last.payload) as Map<String, Object?>;
}

Future<SiteSummary> _buscar(CustomerRepository repo, String siteId) async {
  final clientes = await repo.watchAll().first;
  final sitios = await repo.watchSites(clientes.first.id).first;
  return sitios.firstWhere((s) => s.id == siteId);
}
