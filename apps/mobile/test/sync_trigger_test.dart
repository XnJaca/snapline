import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapline/api/clients/sync_client.dart';
import 'package:snapline/api/models/sync_pull_response_dto.dart';
import 'package:snapline/api/models/sync_push_dto.dart';
import 'package:snapline/api/models/sync_push_response_dto.dart';
import 'package:snapline/api/models/sync_result_dto.dart';
import 'package:snapline/api/models/sync_result_dto_status.dart';
import 'package:snapline/core/network/api_client.dart';
import 'package:snapline/core/session/session_controller.dart';
import 'package:snapline/core/session/session_storage.dart';
import 'package:snapline/data/local/app_database.dart';
import 'package:snapline/data/sync/connectivity.dart';
import 'package:snapline/data/sync/outbox.dart';
import 'package:snapline/data/sync/sync_controller.dart';

import 'support/fakes.dart';

/// Encolar tiene que disparar el push **aunque ningún widget visible esté
/// observando al sincronizador.**
///
/// Es el caso normal, no el raro: se escribe desde pantallas pushed —un
/// formulario, el mapa— y Riverpod 3 **pausa** los listeners de los widgets
/// tapados por una ruta opaca; pausado el provider, se pausan todas sus
/// suscripciones. Un disparo que dependa de `ref.watch` se congela justo cuando
/// alguien guarda algo.
///
/// Acá se simula ese estado: el controlador existe pero nadie lo escucha, que
/// para Riverpod es lo mismo que estar tapado. El bug real se veía en el
/// teléfono como "guardado en el teléfono" que no se apagaba nunca.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encolar dispara el push con el controlador pausado', () async {
    final db = testDatabase();
    final api = _SyncClientQueRegistra();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionStorageProvider.overrideWithValue(
          FakeSessionStorage(buildSession()),
        ),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        syncClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(() async {
      // El container primero: cerrar la base con sus streams vivos se cuelga.
      container.dispose();
      await db.close();
    });

    // Inicializa el controlador **sin ponerle ningún listener**: para Riverpod
    // es lo mismo que estar tapado por la pantalla que guarda. Ni siquiera se
    // puede esperar su `.future` acá — también se pausa.
    container.read(syncControllerProvider);

    // En el teléfono la sesión resuelve con el shell visible, y recién después
    // se navega a la pantalla que guarda. Se reproduce esa secuencia: un
    // listener temporal deja resolver la sesión —sin listeners, hasta el estado
    // queda congelado— y se cierra antes de encolar, que es el momento pausado.
    final sesion = container.listen(sessionControllerProvider, (_, _) {});
    for (var i = 0;
        i < 100 && container.read(sessionControllerProvider).value == null;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(container.read(sessionControllerProvider).value, isNotNull);
    sesion.close();

    final pushesAntes = api.pushes.length;

    await container.read(outboxProvider).enqueue(
      type: SyncOp.siteUpdate,
      targetId: '019feef4-94d8-76fd-b6ee-0e67fc698213',
      payload: {'lat': 9.9281, 'lng': -84.0907},
    );

    // Tope generoso: el disparo es asíncrono.
    for (var i = 0; i < 100 && api.pushes.length == pushesAntes; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      api.pushes.length,
      greaterThan(pushesAntes),
      reason: 'la operación encolada tiene que salir sin esperar al próximo '
          'arranque ni a que el shell vuelva a ser visible',
    );
  });
}

/// Registra cada push y responde `applied` a todo.
class _SyncClientQueRegistra implements SyncClient {
  final pushes = <SyncPushDto>[];

  @override
  Future<SyncPushResponseDto> syncPush({required SyncPushDto body}) async {
    pushes.add(body);
    return SyncPushResponseDto(
      failed: 0,
      results: [
        for (final op in body.operations)
          SyncResultDto(
            clientId: op.clientId,
            status: SyncResultDtoStatus.applied,
            resourceId: op.targetId,
            code: null,
            message: null,
          ),
      ],
    );
  }

  @override
  Future<SyncPullResponseDto> syncPull({String? since}) async {
    return SyncPullResponseDto(
      serverTime: DateTime.utc(2026, 8, 11),
      customers: const [],
      sites: const [],
      projects: const [],
      assignments: const [],
      mediaAssets: const [],
      timeEntries: const [],
      crews: const [],
      crewMembers: const [],
      people: const [],
      deleted: const {},
    );
  }
}
