import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/models/sync_pull_response_dto.dart';

/// El contrato contra una respuesta de verdad.
///
/// Los demás tests arman los DTO a mano, así que un schema mal declarado pasa
/// sin que nadie lo note: se descubre en el teléfono, con el pull entero caído.
/// Pasó — `ProjectUpdate.project` salió a `openapi.json` como objeto
/// **requerido** porque la entity no lo marcaba, el servidor manda solo
/// `projectId`, y `SyncPullResponseDto.fromJson` reventaba con la respuesta
/// completa.
///
/// Este fixture es la respuesta que rompió, recortada a una fila por colección.
void main() {
  const respuesta = '''
{
  "serverTime": "2026-09-03T01:32:31.600Z",
  "customers": [], "sites": [], "assignments": [],
  "crews": [], "crewMembers": [], "timeEntries": [],
  "projects": [{
    "id": "01a0649f-ca76-76b1-bb90-a776836e9ca5",
    "createdAt": "2026-09-03T00:16:29.883Z",
    "updatedAt": "2026-09-03T00:16:29.883Z",
    "companyId": "019ff71d-4a51-72ec-b3dc-664a3d506d4c",
    "deletedAt": null,
    "customerId": "01a062df-0cb2-751c-95f2-73642d6c258a",
    "siteId": "01a062df-0ce1-7718-a154-2149f3cc3093",
    "name": "Prueba", "description": "Prueba", "serviceType": "Roofing",
    "status": "IN_PROGRESS", "clientVisibilityMode": "STAGES",
    "startDate": "2026-09-07", "targetEndDate": "2026-09-30",
    "actualEndDate": null, "publishedAt": null
  }],
  "mediaAssets": [{
    "id": "01a003a4-80b1-7578-b3ef-738b00464836",
    "createdAt": "2026-08-15T04:18:25.927Z",
    "updatedAt": "2026-08-15T04:18:29.309Z",
    "companyId": "019ff71d-4a51-72ec-b3dc-664a3d506d4c",
    "deletedAt": null,
    "projectId": "019ff71d-4a78-72a9-afb0-d2e96960dbc7",
    "kind": "PHOTO", "documentKind": null,
    "storageKey": "co/pr/as.jpg", "mime": "image/jpeg", "bytes": 4337514,
    "width": null, "height": null,
    "capturedAt": "2026-08-15T04:18:27.633Z",
    "uploadedByMembershipId": "019ff71d-4a5c-71b9-aa6f-704f71449bca",
    "deviceLat": null, "deviceLng": null, "checksum": "d72203f5",
    "uploadStatus": "READY", "visibility": "INTERNAL",
    "exifStrippedAt": null, "tags": ["BEFORE"]
  }],
  "people": [
    {"membershipId": "019ff71d-4a5c-71b9-aa6f-704f71449bca",
     "name": "William Ferman", "role": "OWNER"}
  ],
  "projectUpdates": [{
    "id": "01a064a3-4f29-755b-b574-0ed8690438f9",
    "createdAt": "2026-09-03T00:20:20.271Z",
    "updatedAt": "2026-09-03T00:20:20.271Z",
    "companyId": "019ff71d-4a51-72ec-b3dc-664a3d506d4c",
    "deletedAt": null,
    "projectId": "019ff71d-4a78-72a9-afb0-d2e96960dbc7",
    "authorMembershipId": "019ff71d-4a5c-71b9-aa6f-704f71449bca",
    "body": "Faltan clavos, comprar el jueves",
    "visibility": "INTERNAL",
    "approvedByMembershipId": null, "publishedAt": null,
    "assetIds": []
  }],
  "projectStatusChanges": [{
    "id": "01a0649f-cee0-7093-9ba0-f450478d2553",
    "createdAt": "2026-09-03T00:16:29.883Z",
    "updatedAt": "2026-09-03T00:16:29.883Z",
    "companyId": "019ff71d-4a51-72ec-b3dc-664a3d506d4c",
    "deletedAt": null,
    "projectId": "01a0649f-ca76-76b1-bb90-a776836e9ca5",
    "fromStatus": null, "toStatus": "IN_PROGRESS",
    "changedByMembershipId": "019ff71d-4a5c-71b9-aa6f-704f71449bca",
    "deviceRecordedAt": "2026-09-03T00:16:29.920Z",
    "serverReceivedAt": "2026-09-03T00:16:29.920Z"
  }],
  "deleted": {
    "customers": [], "sites": [], "projects": [], "assignments": [],
    "mediaAssets": [], "timeEntries": [], "crews": [], "crewMembers": [],
    "people": [], "projectUpdates": [], "projectStatusChanges": []
  }
}
''';

  test('el pull del servidor se parsea entero', () {
    final dto = SyncPullResponseDto.fromJson(
      jsonDecode(respuesta) as Map<String, dynamic>,
    );

    expect(dto.projects, hasLength(1));
    expect(dto.projectUpdates, hasLength(1));
    expect(dto.projectStatusChanges, hasLength(1));
  });

  test('una nota trae su obra y su autor por id, no como objeto', () {
    // El servidor nunca manda las relaciones: si el schema las exige, el pull
    // entero se cae y el teléfono deja de sincronizar todo, no solo las notas.
    final dto = SyncPullResponseDto.fromJson(
      jsonDecode(respuesta) as Map<String, dynamic>,
    );
    final nota = dto.projectUpdates.single;

    expect(nota.projectId, '019ff71d-4a78-72a9-afb0-d2e96960dbc7');
    expect(nota.authorMembershipId, '019ff71d-4a5c-71b9-aa6f-704f71449bca');
    expect(nota.body, 'Faltan clavos, comprar el jueves');
    expect(nota.assetIds, isEmpty);
  });

  test('un hito sin autor y sin origen se parsea', () {
    final dto = SyncPullResponseDto.fromJson(
      jsonDecode(respuesta) as Map<String, dynamic>,
    );
    final hito = dto.projectStatusChanges.single;

    expect(hito.fromStatus, null);
    expect(hito.toStatus.json, 'IN_PROGRESS');
  });

  test('el createdAt de una obra llega: es el ancla del hilo', () {
    final dto = SyncPullResponseDto.fromJson(
      jsonDecode(respuesta) as Map<String, dynamic>,
    );

    expect(dto.projects.single.createdAt, DateTime.parse('2026-09-03T00:16:29.883Z'));
  });
}
