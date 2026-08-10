import 'dart:convert';

import 'package:drift/drift.dart';

import '../../api/models/customer.dart';
import '../../api/models/project.dart';
import '../../api/models/project_assignment.dart';
import '../../api/models/site.dart';
import '../local/app_database.dart';
import '../local/tables.dart';

/// Del contrato a la fila local.
///
/// Lo que baja del servidor entra como `SYNCED`: ya está allá, no hay nada que
/// empujar. Solo lo que escribe la app nace `PENDING`.
///
/// Las marcas de tiempo llegan como `DateTime`, pero los campos de fecha suelta
/// —`startDate`, `workDate`— llegan como texto: el contrato los declara `date`,
/// no `date-time`. `tryParse` y no `parse`: un formato inesperado no puede
/// tumbar la sincronización entera.
abstract final class SyncMapper {
  static DateTime? _fecha(String? valor) =>
      valor == null ? null : DateTime.tryParse(valor);

  static CustomersCompanion customer(Customer dto) => CustomersCompanion(
    id: Value(dto.id),
    companyId: Value(dto.companyId),
    updatedAt: Value(dto.updatedAt),
    deletedAt: Value(dto.deletedAt),
    syncStatus: const Value(SyncStatus.synced),
    displayName: Value(dto.displayName),
    companyName: Value(dto.companyName),
    email: Value(dto.email),
    phone: Value(dto.phone),
    // El objeto entero, no campo por campo: si el servidor agrega uno, no se
    // pierde por el camino hasta que la app lo conozca.
    billingAddress: Value(
      dto.billingAddress == null ? null : jsonEncode(dto.billingAddress!.toJson()),
    ),
    photoReleaseGrantedAt: Value(dto.photoReleaseGrantedAt),
  );

  static SitesCompanion site(Site dto) => SitesCompanion(
    id: Value(dto.id),
    companyId: Value(dto.companyId),
    updatedAt: Value(dto.updatedAt),
    deletedAt: Value(dto.deletedAt),
    syncStatus: const Value(SyncStatus.synced),
    customerId: Value(dto.customerId),
    address: Value(jsonEncode(dto.address.toJson())),
    lat: Value(dto.lat?.toDouble()),
    lng: Value(dto.lng?.toDouble()),
    geofenceRadiusM: Value(dto.geofenceRadiusM?.toInt()),
  );

  static ProjectsCompanion project(Project dto) => ProjectsCompanion(
    id: Value(dto.id),
    companyId: Value(dto.companyId),
    updatedAt: Value(dto.updatedAt),
    deletedAt: Value(dto.deletedAt),
    syncStatus: const Value(SyncStatus.synced),
    customerId: Value(dto.customerId),
    siteId: Value(dto.siteId),
    name: Value(dto.name),
    description: Value(dto.description),
    serviceType: Value(dto.serviceType),
    // Se guarda el valor del contrato, no el índice del enum: un estado nuevo en
    // el servidor llega como texto y no rompe la base local.
    status: Value(dto.status.json ?? ''),
    clientVisibilityMode: Value(dto.clientVisibilityMode.json ?? ''),
    startDate: Value(_fecha(dto.startDate)),
    targetEndDate: Value(_fecha(dto.targetEndDate)),
    actualEndDate: Value(_fecha(dto.actualEndDate)),
  );

  static ProjectAssignmentsCompanion assignment(ProjectAssignment dto) =>
      ProjectAssignmentsCompanion(
        id: Value(dto.id),
        companyId: Value(dto.companyId),
        updatedAt: Value(dto.updatedAt),
        deletedAt: Value(dto.deletedAt),
        syncStatus: const Value(SyncStatus.synced),
        projectId: Value(dto.projectId),
        crewId: Value(dto.crewId),
        membershipId: Value(dto.membershipId),
        workDate: Value(_fecha(dto.workDate) ?? DateTime.fromMillisecondsSinceEpoch(0)),
        plannedHeadcount: Value(dto.plannedHeadcount?.toInt()),
      );
}
