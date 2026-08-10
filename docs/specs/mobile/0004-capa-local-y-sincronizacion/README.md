---
id: SPEC-0004
title: "Capa local y sincronización"
aliases:
  - "SPEC-0004: Capa local y sincronización"
type: spec
platform: mobile
status: en-implementacion
goal: "Ninguna pantalla lee de la red —todas observan la base local— y toda escritura hecha sin señal llega al servidor sola cuando vuelve, exactamente una vez."
apps:
  - mobile
  - api
depends_on:
  - "0001-login-movil"
domain:
  - proyecto
  - cliente
  - registro-de-tiempo
  - contenido
frente: plataforma
created: 2026-08-09
updated: 2026-08-09
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0004: Capa local y sincronización

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0001-login-movil/README|SPEC-0001]]
> - Frente: `plataforma`

---

## Problema

`apps/mobile/CLAUDE.md` dice que **la UI nunca lee de la red**: lee de Drift y
observa sus streams. Hoy `lib/data/` no existe, así que esa convención no está
implementada y cada pantalla que se escriba sin ella nace con el camino
equivocado — y retrofitear offline después significa reescribir todas.

No es una preferencia de arquitectura. Es el producto: la app se usa en obras de
Maryland donde la cobertura se cae, y la regla 9 dice que **marcar asistencia
nunca puede fallar**. Un diseño donde la pantalla espera al servidor tiene un
camino distinto para "sin señal", y ese camino es el que nadie prueba.

Esta capa se construye **antes** que las pantallas de Proyectos y Clientes, no
después.

## Prerequisitos en `apps/api`

Lo que sigue bloquea todo lo demás y se arregla primero. **No es alcance opcional:
sin esto el resto no se puede implementar.**

Los cinco salieron de verificar el contrato contra el código, no de leerlo. El
primero es un agujero de permisos que ya está en `main`.

### 0. `/sync` no autoriza por operación — GRAVE

`sync.controller.ts` gatea el `POST /sync` entero con `@RequirePermission('time.clock')`,
que tienen `OWNER`, `ADMIN`, `FOREMAN` y `WORKER`. Pero adentro del lote procesa
`customer.create` y `project.create`, cuyos endpoints REST exigen `customers.write`
y `projects.write` — **solo `OWNER` y `ADMIN`**.

O sea: hoy un `WORKER` da de alta clientes y proyectos por la puerta de sync,
saltándose el permiso que le cierra la puerta REST. Es la regla 7 incumplida — el
endpoint declara su permiso, las operaciones de adentro no.

Agregar `customer.update` y `project.update` **empeora** esto: pasaría a poder
editar clientes y obras de toda la empresa.

Arreglo: cada tipo de `SYNC_OPERATIONS` declara el permiso que necesita y el
servicio lo verifica **antes de aplicar cada operación**. La que no pasa vuelve
`failed` con `FORBIDDEN`; las demás del lote entran igual, como ya hace con
cualquier otro fallo. El gate del endpoint se queda en `time.clock`, que es el
mínimo para que un trabajador pueda empujar su marcaje.

**No cambia la política de roles, hace que sync la respete.**

### 1. El pull devuelve datos sin tipo

`SyncPullResponseDto` declara sus colecciones como `unknown[]` con
`@ApiProperty({ type: [Object] })`, y en `openapi.json` salen así:

```json
"customers": { "type": "array", "items": { "type": "object" } }
```

Es exactamente lo que advierte la regla 8: el cliente Dart lo tipa como
`dynamic`, **parsea la respuesta, descarta todo y no falla**. No hay nada tipado
que guardar en Drift.

Arreglo: declarar el tipo real de cada colección (`Customer[]`, `Site[]`,
`Project[]`, `ProjectAssignment[]`, `MediaAsset[]`, `TimeEntry[]`) y regenerar
`openapi.json`.

**Lo mismo pasa con las direcciones.** `customer.billing_address` y
`site.address` son `jsonb` sin forma declarada, así que llegan a Flutter como
`dynamic`. Su forma ya está definida en
[[../../../domain/cliente|la ficha de cliente]] y hay que declararla como DTO
—uno solo, compartido por los dos campos— en el mismo pasaje.

### 2. El push no acepta correcciones

`SYNC_OPERATIONS` tiene cinco operaciones y **todas son altas**:

```
customer.create · project.create · media.register · timeEntry.clockIn · timeEntry.clockOut
```

Corregir el nombre de una obra o el teléfono de un cliente sin señal no tiene
cómo encolarse. Hacen falta `customer.update` y `project.update`, con su DTO de
payload validado igual que las demás.

**Y falta `site.create`.** Lo encontraron dos revisores por separado: agregar una
propiedad a un cliente **que ya existe** no tiene camino offline. El único modo es
`POST /customers/:id/sites`, que no pasa por la bandeja, y `CustomersService.update()`
descarta el `site` anidado a propósito:

```ts
const { site: _site, id: _id, ...rest } = dto;
```

Es el caso de todos los días: William ya cargó a Martínez y arranca un segundo
trabajo en otra dirección del mismo cliente. Sin `site.create` no se puede crear
esa obra sin señal, porque no hay `site_id` que ponerle.

`site.update` entra también si se va a poder corregir una dirección — hoy no
existe ni siquiera un `PATCH` REST para eso.

### 3. La idempotencia se apoya en que el recurso no exista

`alreadyApplied()` decide "ya aplicado" preguntando si **ya hay una fila con ese
id**. Funciona para los `create` porque el id lo genera el dispositivo. Para un
`update` el recurso **siempre** existe, así que ese mismo criterio devolvería
`duplicate` sin aplicar nunca la corrección.

Arreglo: una tabla de operaciones aplicadas, con el `clientId` del dispositivo
como clave. Sirve igual para altas y correcciones, y no depende de si el recurso
está. Es la regla 19, que este spec cita como no negociable.

### 4. `deleted[]` no emite bajas de `site` ni de `project_assignment`

`pull()` los trae vivos pero no los incluye en `deleted{}`, y las dos entidades
tienen `deleted_at`. Este spec declara las dos como tablas locales con borrado
suave, así que su criterio de *"un borrado en el servidor llega como marca"* no se
puede verificar para ellas: el servidor nunca las emite.

### 5. No hay forma de distinguir un conflicto de una falla

`SyncResultDto.status` admite `applied | duplicate | failed`, nada más. Pero la
regla 12 exige que un conflicto de `time_entry` se marque y **lo mire un humano**,
que es otra cosa que un fallo reintentable.

Lo que sí existe son códigos concretos. **Estos y solo estos** pasan una fila de
`time_entry` a `CONFLICT`:

| `code` | Qué pasó |
|---|---|
| `TIME_ENTRY_ALREADY_OPEN` | Ya había una entrada abierta para esa persona |
| `TIME_ENTRY_ALREADY_CLOSED` | La salida llegó a un registro ya cerrado |

Cualquier otro código es un `failed` reintentable y **no** marca conflicto. Sin
esta tabla, cada implementador decide distinto qué es un conflicto — justo en el
agregado donde la regla 12 no lo permite.

## Alcance

### Entra

- Tablas Drift para lo que el pull ya devuelve: `customer`, `site`, `project`,
  `project_assignment`, `media_asset`, `time_entry`.
- **Bandeja de salida en una tabla**, no en memoria: sobrevive a que el sistema
  mate la app.
- Un repositorio por agregado, que expone streams y **es lo único que las
  pantallas conocen**.
- Sincronizador: pull incremental con cursor, push de la bandeja, reintento.
- `sync_status` por fila: `PENDING | SYNCING | SYNCED | CONFLICT`.
- Los cinco arreglos de contrato de arriba, incluido el de permisos.

### No entra

- **Sincronización en segundo plano con la app cerrada.** Sincroniza al abrir,
  al volver la red y al pedirlo a mano. `WorkManager`/`BGTaskScheduler` es un
  spec propio.
- **Subida de archivos de foto.** `media.register` registra el metadato; el
  binario a Backblaze tiene su propio camino y su propio spec.
- **Resolución de conflictos de `time_entry`.** Acá solo se **marca** `CONFLICT`
  (regla 12). La pantalla que lo resuelve es otro spec.
- Paginar el pull inicial. Una empresa del tamaño de la de William entra en una
  respuesta; cuando no entre, se agrega cursor por página.

## Modelo de dominio afectado

- [[../../../domain/proyecto|proyecto]], [[../../../domain/cliente|cliente]],
  [[../../../domain/registro-de-tiempo|registro-de-tiempo]] y
  [[../../../domain/contenido|contenido]] — se replican en local, **sin agregar
  ni renombrar campos**. La tabla local es un espejo, no un modelo paralelo.

No se agrega nada al modelo. Los campos que la capa local suma —`sync_status`,
`deleted_at` local, la bandeja— son de infraestructura de sincronización y no
viajan al servidor.

## Las reglas que esto tiene que cumplir

Salen de las reglas duras y no se negocian al implementar:

| Regla | Qué implica acá |
|---|---|
| 18 — IDs UUIDv7 en el cliente | El registro nace con su id definitivo. **Nunca** un id temporal que haya que reconciliar. |
| 19 — escrituras idempotentes | Cada operación lleva su clave y **se reintenta con esa misma**. El servidor responde `duplicate`, que es éxito. |
| 20 — borrado suave | Nada se borra duro de una tabla que sincroniza. El pull trae `deleted[]` y eso marca, no elimina. |
| 12 — las horas no se sobrescriben | Un conflicto en `time_entry` se marca `CONFLICT` y **lo mira un humano**. Todo lo demás es última escritura gana. |
| 10 — dos marcas de tiempo | `device_recorded_at` sale del dispositivo, `server_received_at` del servidor. La capa local **no** los confunde ni rellena el segundo. |

## Comportamiento sin señal

Es el caso normal, no la excepción: **no hay una ruta distinta que recorrer**.

| Situación | Comportamiento |
|---|---|
| Sin red, leyendo | Idéntico a con red: la pantalla observa Drift. |
| Sin red, escribiendo | Se escribe en local con `PENDING` y entra a la bandeja. La UI la muestra al instante. |
| Vuelve la red | El sincronizador vacía la bandeja en orden de `occurredAt` y marca `SYNCED`. |
| Reintento tras corte | Misma clave de idempotencia; el servidor responde `duplicate` y la fila sale de la bandeja igual. |
| Token vencido sin red | Se sigue capturando. Lo que se pierde es sincronizar, no trabajar (regla 9). |
| Falla una operación del lote | Las demás entran igual. La que falló queda en la bandeja con su error. |

## Flujo

```
Pantalla ──observa──▶ Drift ◀──escribe── Sincronizador ──▶ API
   │                    ▲                      │
   └──── escribe ───────┘                      │
        (PENDING + bandeja) ───────────────────┘
```

Una escritura desde la UI **nunca** llama al API. Escribe en Drift, encola, y
devuelve. El sincronizador es el único que habla con la red.

## Contrato de API

El endpoint ya existe. Cambian sus tipos, su lista de operaciones, cómo autoriza
cada una y qué emite en `deleted`:

```http
GET  /api/sync?since=2026-08-09T12:00:00Z
POST /api/sync
```

El cursor del próximo pull es el `serverTime` que devuelve el servidor, **nunca
el reloj del dispositivo** — eso ya está resuelto en el API y hay que respetarlo
en el cliente.

## Criterios de aceptación

- [x] `openapi.json` declara el tipo real de cada colección del pull, y el
      cliente Dart generado las expone tipadas y no como `dynamic`.
- [x] Un `WORKER` que manda `customer.create` o `project.create` por `/sync`
      recibe `failed` con `FORBIDDEN`, y las demás operaciones de su lote se
      aplican igual.
- [x] `customer.update`, `project.update` y `site.create` existen en
      `SYNC_OPERATIONS`, validan su payload y tienen su caso en `edge-cases/`.
- [x] Crear una propiedad para un cliente **que ya sincronizó**, sin señal, llega
      al servidor y queda colgada de ese cliente.
- [x] Mandar dos veces el mismo `customer.update` lo aplica una sola vez, y la
      segunda vuelve `duplicate`.
- [x] `pull().deleted` incluye `sites` y `assignments`.
- [ ] Solo `TIME_ENTRY_ALREADY_OPEN` y `TIME_ENTRY_ALREADY_CLOSED` dejan una fila
      en `CONFLICT`; cualquier otro código la deja reintentable.
- [x] `billing_address` y `site.address` salen al contrato con sus seis campos,
      no como objeto vacío, y comparten el mismo DTO.
- [x] Ninguna pantalla importa un cliente de `lib/api/`: se verifica con una
      prueba que recorre `lib/features/` y falla si aparece.
- [x] Una escritura con la red caída queda visible en la UI al instante y con
      `sync_status = PENDING`.
- [x] Reenviar la misma operación dos veces deja **una** fila en el servidor, y
      la segunda vuelve `duplicate`.
- [x] Matar la app con la bandeja llena y reabrirla no pierde ninguna operación.
- [ ] Un `time_entry` con escritura concurrente queda `CONFLICT` y **no** se
      sobrescribe solo.
- [x] Un borrado en el servidor llega al dispositivo como marca, no como
      `DELETE`, y la fila deja de listarse.
- [x] El cursor que se guarda es el `serverTime` de la respuesta.
- [x] Una operación que falla no impide que las demás del lote se apliquen.

## Riesgos / consideraciones

**El pull sin paginar puede crecer.** Hoy una empresa entra en una respuesta.
El día que no entre, esto se nota como un arranque lento, no como un error — vale
la pena medir el tamaño de la respuesta desde el principio.

**`media.register` sin subida de binario deja fotos a medias.** Una foto
registrada cuyo archivo todavía no subió es una fila con metadato y sin imagen.
La pantalla de Fotos tiene que saber mostrar ese estado; se define en su spec, y
conviene no olvidarlo.

**El generador de Dart es sensible al orden.** `swagger_parser` corre antes que
`build_runner`, y `lib/api/` está hoy generado de antes de que existiera `/sync`.
Regenerar es parte de esto, no un paso aparte.

## ADRs relacionados

- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]] — Drift y la
  arquitectura de la app
- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — por qué el tipo
  vacío del pull es un problema de contrato y no un detalle

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-09 | borrador | Creado. Sale de decidir offline-first de verdad en vez de leer del API con deuda registrada. Los dos prerequisitos de `apps/api` se encontraron leyendo el contrato: el pull devuelve `unknown[]` y el push no acepta correcciones. |
| 2026-08-09 | borrador | Revisado con `spec-reviewer`. **Un hallazgo grave**: `/sync` gatea el endpoint entero con `time.clock`, así que un `WORKER` puede crear clientes y proyectos saltándose `customers.write`/`projects.write`. Sumados cuatro huecos más que no se veían leyendo el documento: falta `site.create` —lo encontraron dos revisores por separado—, la idempotencia se apoya en que el recurso no exista y por eso rompe con los `update`, `deleted[]` no emite `site` ni `project_assignment`, y no había señal para distinguir un conflicto de `time_entry` de una falla común. |
| 2026-08-09 | en implementación | Primera mitad, PR #2 mergeado: los cinco arreglos de contrato —incluido el agujero de permisos— y la capa local leyendo de Drift. Verificado en teléfono real con el internet apagado. |
| 2026-08-09 | en implementación | Bandeja de salida: encolar, empujar el lote, y el resultado de vuelta a la fila local. Verificado contra el API que una escritura encolada llega **exactamente una vez** aunque se reintente. Queda sin cerrar el criterio de `CONFLICT` de `time_entry`: los códigos están mapeados, pero no hay forma de producir uno hasta que exista el marcaje desde el móvil. |
