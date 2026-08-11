---
id: SPEC-0008
title: "Asistencia en el móvil"
aliases:
  - "SPEC-0008: Asistencia en el móvil"
type: spec
platform: mobile
status: en-implementacion
goal: "Marcar entrada y salida —propia o por otro que fue a la misma obra— nunca falla: sin señal, sin GPS, sin cámara y sin asignación cargada siempre queda el registro con lo que haya y su bandera, y un choque de horas al sincronizar queda en `CONFLICT` sin sobrescribir nada."
apps:
  - mobile
  - api
depends_on:
  - "0003-arquitectura-de-navegacion"
  - "0004-capa-local-y-sincronizacion"
  - "0007-ubicacion-de-la-propiedad-en-el-mapa"
domain:
  - registro-de-tiempo
  - cuadrilla
  - proyecto
  - contenido
frente: campo
created: 2026-08-10
updated: 2026-08-11
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0008: Asistencia en el móvil

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0003-arquitectura-de-navegacion/README|SPEC-0003]],
>   [[../0004-capa-local-y-sincronizacion/README|SPEC-0004]],
>   [[../0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]]
> - Frente: `campo`

---

## Problema

**Hoy** es la primera pestaña de un trabajador y sigue siendo un `PlaceholderScreen`.
Es la única pantalla que [[../../../product/vision|la visión]] le promete: *dónde
trabajo hoy, marcar entrada, tomar fotos, marcar salida*. De las cuatro, ninguna
existe.

La pregunta textual de William fue **cómo saber si el trabajador realmente se
presentó**, y es la que abre [[../../../adr/0003-asistencia-geocerca-foto/README|ADR-0003]].
Sin esta pantalla no hay horas que reportar, y sin horas el frente comercial factura
sobre lo que alguien recuerde.

Y hay una deuda concreta que solo esto cierra: **SPEC-0004 tiene dos criterios que no
se pueden verificar** porque no hay forma de producir un conflicto de `time_entry`
desde el móvil. Los códigos están mapeados en `synchronizer.dart` y nunca se
ejercitan. Un camino de código que nunca corrió no está implementado, está escrito.

## La escalera de evidencia

La decisión de producto de este spec, y la que lo separa de cualquier app de
asistencia con selfie.

**La evidencia es la ubicación. La foto es lo que queda cuando no hay ubicación.**

| Lo que el teléfono consigue | Qué pide la app | Qué queda registrado |
|---|---|---|
| GPS disponible | Nada más. Un toque y listo | `lat`/`lng`, y el servidor calcula distancia y geocerca |
| GPS denegado o sin fix | **La foto del frente de obra** | El asset, y la bandera `NO_LOCATION` |
| Cámara también denegada | Nada. Se marca igual | Hora y bandera doble |

Nunca se pide un selfie. La cámara apunta al trabajo, no a la persona: prueba lo
mismo que importa —que estuvo ahí— y de paso alimenta el contenido, que es el
destino de toda foto en este producto.

**Nada de esto bloquea** (regla 9 y ADR-0003, alternativa C). La escalera decide qué
se pide, no qué se permite: quien deniega los dos permisos marca igual y lo resuelve
el admin con las banderas a la vista.

> La foto nunca fue obligatoria. ADR-0003 dice *"captura GPS y una foto… no bloquea,
> registra la evidencia y levanta una bandera"*, y la bandera `NO_PHOTO` existe desde
> la primera migración. Este spec no cambia el ADR: le pone la regla de cuándo pedir
> qué, que el ADR dejó sin escribir.

### Los metadatos de la foto no reemplazan al GPS

Se pueden leer, y aun así **ninguno sirve para lo que se los querría usar**. Queda
escrito acá para que no se intente al implementar:

- **El GPS del EXIF sale del mismo permiso que ya fue denegado.** Una foto solo lleva
  coordenadas si la app tenía permiso de ubicación al capturarla, y el caso que pide
  la foto es precisamente el que no lo tiene. Viene vacío, siempre.
- **El EXIF se edita con cualquier app gratis.** Es el argumento de ADR-0003 aplicado
  a otro campo: si el servidor confía en un dato que el dispositivo controla, el
  control es decorativo. Lo mismo que ya se hace con `withinGeofence`.
- **Snapline borra el EXIF a propósito.** `MediaService.markUploaded()` llama a
  `stripExif()` en toda foto. Es lo que evita publicar la casa de un cliente con sus
  coordenadas adentro (regla 17). Un metadato que se quiera conservar se **lee en el
  dispositivo antes de subir** y viaja como campo propio — `RegisterAssetDto` ya tiene
  `deviceLat`, `deviceLng`, `capturedAt`, `width`, `height` y `bytes`.

**El que sí aporta es `capturedAt`**, y no por la ubicación: distingue una foto tomada
en el momento de una vieja elegida de la galería, que es el fraude realista en este
flujo. Se resuelve mejor en la captura que en la validación — **la cámara se abre en
modo directo, sin acceso a galería** — y `capturedAt` queda como el respaldo que lo
delata si el modo directo se saltea.

> Si además se quiere una bandera para "foto no tomada en el momento", es un campo
> nuevo en `flags` y eso toca [[../../../domain/registro-de-tiempo|la ficha del
> agregado]]: se decide con `domain-guardian` antes de implementar, no durante.

## Prerequisitos en `apps/api`

Como en [[../0004-capa-local-y-sincronizacion/README|SPEC-0004]]: salieron de
verificar el contrato contra el código, no de leerlo. **Sin esto el resto no se puede
implementar.**

### 0. Marcar por otro autoriza solo por rol, sin relación con la obra

```ts
// assertCanRecordForOthers, time-entries.service.ts:207
if (!me || !['OWNER', 'ADMIN', 'FOREMAN'].includes(me.role)) throw …
```

Cualquier `FOREMAN` de la empresa puede marcar por **cualquier** membresía, aunque no
tenga nada que ver con esa obra ni con esa persona. Hoy no se nota porque ninguna
pantalla lo ofrece; **este spec es el primero que lo ofrece.**

El criterio ya está decidido en
[[../../../product/vision|la visión, "Quién puede fichar por otra persona"]] y este
spec lo implementa tal cual:

- **El dueño y el administrador quedan sin acotar.** Responden por la empresa entera.
- **Para el `FOREMAN` el criterio es la obra, no la cuadrilla.** Quien fue a la obra
  ese día ficha por quien también fue, sin importar de qué cuadrilla sea cada uno. Sale
  de `project_assignment` con su `work_date`, y resuelve solo la cobertura entre
  encargados.
- **Se aplica como bandera, no como bloqueo.** Una asignación sin cargar dejaría a la
  cuadrilla sin poder fichar, y la regla 9 no lo permite — más aún hoy, que
  `project_assignment` está vacío porque la pantalla que lo llena no existe.

Arreglo: se registra siempre, y cuando quien marca no estaba asignado a esa obra ese
día se levanta la bandera. El nombre sigue la forma de las que ya existen:
`RECORDER_NOT_ASSIGNED`.

> **Es un valor nuevo en `flags`, así que toca el modelo.** Va a
> [[../../../domain/registro-de-tiempo|la ficha del agregado]], que hoy lista ocho
> banderas y no esta. Se pasa por `domain-guardian` antes de implementar.

### 1. El `WORKER` no puede leer sus propias horas

`'time.read': ['OWNER', 'ADMIN', 'FOREMAN', 'ACCOUNTANT']`. Un trabajador puede
fichar y no puede consultar lo que fichó.

Por el pull de `/sync` las recibe igual —y solo las suyas, con el arreglo de la rama
`fix/sync-pull-filtra-clientes-por-rol`—, así que la pantalla funciona. Pero la tabla
de permisos dice una cosa y lo que baja al teléfono dice otra, y esa clase de
desacuerdo se arregla antes de que alguien lo resuelva mal.

Arreglo: `WORKER` entra en `time.read`, y `TimeEntriesService.list()` acota a las
propias cuando el rol no tiene alcance sobre las de otros.

### 2. El pull no baja cuadrillas, ni miembros, ni nombres

El foreman no puede marcar por quien fue a la obra si no sabe quién fue. La
[[../../../domain/cuadrilla|ficha de cuadrilla]] ya lo declara —*"se cachea en el
dispositivo; el foreman necesita ver a su gente sin señal para poder marcar por
ellos"*— y el pull devuelve seis colecciones, ninguna de ellas.

**`project_assignment` no alcanza sola**: sus dos referencias son opcionales, así que
una asignación puede colgar de un `crew_id` en vez de un `membership_id`. Resolver
"quién está asignado a esta obra hoy" cuando la obra tiene asignada una cuadrilla
entera exige `crew_member`.

Faltan entonces `crew`, `crew_member` y **la identidad de cada membresía** (nombre y
rol) para mostrar personas y no UUIDs. Bajan acotadas a lo que aparece en las obras de
la persona.

**`pay_rate_cents` no baja al teléfono, con ningún rol.** Es lo que gana cada persona
y no hace falta para marcar.

### 3. El scope por rol del pull cubre al `WORKER` y no al `FOREMAN`

`sync.service.ts` filtra con `const esWorker = tenant.role === 'WORKER'`. Un foreman
se baja al teléfono la cartera completa de clientes de la empresa y las horas de todos
—con `pay_rate_cents_snapshot` y las coordenadas de cada marcaje—, aunque solo lidere
una cuadrilla.

Arreglo: el filtro pasa a ser por alcance y no por rol. El foreman recibe sus obras
asignadas, las de su cuadrilla, y las horas de su gente. Nada más.

> El PR #5 cerró la mitad: acotó las seis colecciones, pero solo para `WORKER`. La
> otra mitad es este prerequisito, y la abre este spec porque es el primero que le da
> al foreman una pantalla donde esos datos importan.

### 4. `POST /media` y `GET /media/:id/url` salen al contrato como `{}`

Es la regla 8 otra vez, y en el peor lugar:

```json
"responses": { "201": {} }
```

`MediaService.register()` devuelve `{ asset, uploadUrl }`, una forma declarada en el
`.service.ts` y no en un DTO, así que el plugin no la introspecciona. El cliente Dart
la tipa como `dynamic`: **parsea la respuesta, descarta la `uploadUrl` y no falla.**
Sin esa URL no hay dónde subir el binario.

Arreglo: un DTO para las dos respuestas, con `@ApiOkResponse({ type: ... })`, y
regenerar `openapi.json`.

### 5. Registrar una foto por la bandeja no devuelve dónde subirla

`media.register` está en `SYNC_OPERATIONS` y el resultado de una operación de sync es
solo el `id`. La `uploadUrl` que devuelve el camino REST no tiene por dónde volver.

Y no hay endpoint para pedirla después: `GET /media/:id/url` es la **de descarga**
(`downloadUrl`), no la de subida.

Arreglo: `GET /media/:id/upload-url` para un asset ya registrado, con `media.capture`.
Es lo que permite que la foto se registre sin señal por la bandeja y el binario suba
más tarde, que es el caso normal.

### 6. `method` dice `FOREMAN` aunque haya marcado el dueño

```ts
method: targetMembershipId === tenant.membershipId ? 'SELF' : 'FOREMAN',
```

El enum tiene tres valores —`SELF`, `FOREMAN`, `ADMIN`— y el código usa dos. Cuando
William marca por alguien, el registro dice que lo hizo un foreman.

Hoy no se nota porque nadie marca por nadie: **este spec es el primero que ejercita
esa línea**. Y es un dato falso en el campo que existe para la regla 12 — el rastro de
quién hizo qué es defensa legal en una disputa de horas, y ahí "lo marcó un foreman"
cuando lo marcó el dueño es exactamente lo que no puede pasar.

Arreglo: el `method` sale del rol de quien marca, no de si marcó por sí mismo.

## Alcance

### Entra

- **Pantalla Hoy**: las obras donde la persona tiene asignación para hoy, y el estado
  de su jornada.
- **Marcar entrada y salida**, con la escalera de evidencia de arriba.
- **Foto de respaldo**: cámara, guardado local, registro por la bandeja y **subida del
  binario con reintento**. Sin esto la evidencia nunca llega al servidor.
- **Marcar por otro**, con el criterio de la obra y su bandera: es la alternativa B de
  ADR-0003 como método secundario.
- **Ver a dónde ir.** La obra de hoy muestra su dirección y su punto, y se abre en la
  app de mapas del teléfono. Viene de
  [[../0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]], que llena el dato
  y **no puede mostrarlo**: su pantalla cuelga de la ficha de propiedad, detrás de
  `customers.read`, y un `WORKER` nunca llega ahí. "Hoy" es la única pantalla que sí
  abre, así que el dato se muestra acá o no le llega a quien lo necesita.
- **Mis horas de la semana** en solo lectura, con su estado y sus banderas.
- Tablas locales `time_entry`, `media_asset`, `crew`, `crew_member` y la identidad de
  las membresías.
- Los seis arreglos de contrato de arriba.

### No entra

- **La alerta al llegar a la obra.** Es lo siguiente de este frente y va en su propio
  spec: exige el permiso de ubicación **"Siempre"**, monitoreo de regiones en segundo
  plano y notificaciones locales — nada de lo cual existe hoy en la app. Ver los
  riesgos.
- **Resolver el conflicto de `time_entry`.** Acá se **marca** y se muestra, que es lo
  que SPEC-0004 pide. La pantalla que lo resuelve sigue siendo otro spec.
- **Aprobar y rechazar horas.** `time.approve` sigue siendo de `OWNER` y `ADMIN`, como
  la visión decidió: el foreman marca y levanta banderas, y el dueño es quien las mira.
  Ese reparto es lo que sostiene que marcar por otro sea bandera y no bloqueo.
- **Corregir una hora ya marcada.** Toda corrección deja rastro y eso es una pantalla
  con su propio diseño; hoy se rechaza y se marca de nuevo.
- **Fijar el punto y el radio de la obra.** Es [[../0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]],
  del que este depende.
- **La galería de fotos del proyecto.** Acá solo existe la foto de respaldo del
  marcaje. La captura libre es su propio spec.
- Nómina, horas extra y overtime. Fuera del producto, no de este spec
  ([[../../../product/vision|"Qué NO somos"]]).

## Modelo de dominio afectado

- [[../../../domain/registro-de-tiempo|registro-de-tiempo]] — el agregado central.
  **No se le agrega ni se le renombra nada**: la tabla local es un espejo.
- [[../../../domain/cuadrilla|cuadrilla]] — se cachea para marcar por otros, como su
  ficha ya declara.
- [[../../../domain/proyecto|proyecto]] y [[../../../domain/contenido|contenido]] —
  se leen; la foto de respaldo es un asset como cualquier otro.

## Las reglas que esto tiene que cumplir

| Regla | Qué implica acá |
|---|---|
| 9 — marcar nunca falla | Sin red, sin GPS, sin permiso de cámara: se registra igual. **No hay una sola rama de código que devuelva "no se pudo marcar".** |
| 10 — dos marcas de tiempo | `device_recorded_at` sale del dispositivo; `server_received_at` lo pone el servidor. El móvil **no** rellena el segundo. |
| 11 — `is_mock_location` siempre | Se manda en cada marca. En iOS el sistema no expone el dato: se manda `false` y **eso no es lo mismo que "verificado"**. |
| 12 — las horas no se sobrescriben | `TIME_ENTRY_ALREADY_OPEN` y `TIME_ENTRY_ALREADY_CLOSED` dejan la fila en `CONFLICT` y ahí se queda hasta que la mire un humano. |
| 13 — la tarifa se congela al aprobar | El móvil **no** manda ni muestra `pay_rate_cents`. Lo congela el servidor. |
| 18 · 19 · 20 | El `time_entry` nace con su UUIDv7, se encola con su clave de idempotencia, y nada se borra duro. |

## Comportamiento sin señal

Es el caso principal del agregado, no una degradación: la obra sin cobertura es donde
esto se usa.

| Situación | Comportamiento |
|---|---|
| Sin red, marcando | Se escribe en Drift con `PENDING` y entra a la bandeja. El cronómetro arranca al instante. |
| Sin red, con foto | El archivo queda en el dispositivo; `media.register` va a la bandeja y el binario sube cuando haya red. |
| Sin GPS | Se pide la foto. Si tampoco hay cámara, se marca con hora y las dos banderas. |
| GPS lento | Hay un tope, y **pasado el tope cuenta como "sin GPS"**: entra la escalera y se pide la foto. La jornada no espera al satélite. |
| Vuelve la red | La bandeja se vacía en orden de `occurredAt`: la entrada nunca se aplica después de su salida. |
| Ya había una entrada abierta | El servidor responde `TIME_ENTRY_ALREADY_OPEN`, la fila queda `CONFLICT` y la pantalla lo dice. **No se reintenta solo.** |
| Token vencido sin red | Se sigue marcando. Lo que se pierde es sincronizar, no trabajar. |

## Flujo de usuario

```
Hoy ──▶ [obra asignada] ──▶ Marcar entrada
                                   │
                    ┌──────────────┴──────────────┐
              ¿hay GPS?                      ¿no hay GPS?
                    │                             │
              se marca ya                   pide la foto
                    │                             │
                    └──────────────┬──────────────┘
                                   ▼
                        PENDING + bandeja + cronómetro
                                   ▼
                            Marcar salida
```

Entrada en **dos toques** desde abrir la app: la obra y el botón. Si tiene una sola
asignación para hoy, en uno.

## Contrato de API

Los endpoints existen. Cambia quién puede qué, qué baja el pull y qué operaciones
acepta la bandeja.

Las operaciones de marcaje ya están en `SYNC_OPERATIONS` y **no cambian su payload**.
`withinGeofence` y `distanceM` no se mandan nunca: los deriva el servidor y aceptarlos
del dispositivo volvería decorativo el control (ADR-0003).

### El pull suma tres colecciones

```http
GET /api/sync?since=2026-08-10T12:00:00Z
```

```jsonc
{
  "crews":       [{ "id": "…", "name": "Cuadrilla A", "foremanMembershipId": "…", "color": "#…" }],
  "crewMembers": [{ "id": "…", "crewId": "…", "membershipId": "…",
                    "fromDate": "2026-01-15", "toDate": null }],
  // Solo para poner un nombre donde hoy iría un UUID. `name` sale de `app_user`,
  // no de `membership`, así que es un DTO propio y no la entity.
  "people":      [{ "membershipId": "…", "name": "Luis Martínez", "role": "WORKER" }],
  "serverTime": "2026-08-10T12:30:00Z"
}
```

**`payRateCents` no aparece en `people` ni en ninguna otra colección**, con ningún
rol. Es lo que gana cada persona y no hace falta para marcar. Va con
`@ApiHideProperty()` si llegara a vivir en una entity que se serialice.

Las tres bajan acotadas por alcance: las cuadrillas que la persona lidera o integra,
sus miembros vigentes, y solo la gente que aparece en ellas.

### La URL de subida de un asset ya registrado

```http
GET /api/media/:id/upload-url        # media.capture
```

```json
{ "url": "https://…", "expiresInSeconds": 600 }
```

Misma forma que `downloadUrl`, que ya devuelve `{ url, expiresInSeconds }`. Es lo que
permite registrar la foto por la bandeja sin señal y subir el binario después — hoy la
`uploadUrl` solo vuelve por el camino REST de `POST /media`, que la bandeja no usa.

**Y las dos respuestas se declaran con DTO.** Hoy `POST /media` sale a `openapi.json`
como `"201": {}` porque `MediaService.register()` devuelve una forma declarada en el
`.service.ts`. Con su DTO y `@ApiOkResponse({ type: … })` el cliente Dart deja de
tiparlas `dynamic`.

### Lo que no cambia

`SYNC_OPERATIONS` no suma ninguna operación: `timeEntry.clockIn` y
`timeEntry.clockOut` ya están y su payload sirve tal cual. Aprobar y rechazar siguen
siendo solo REST, de `OWNER` y `ADMIN`, y no bajan al móvil.

## UI

**Hoy** — encabezado con la obra y, si hay jornada abierta, el cronómetro corriendo
con `tabularFigures` para que no se mueva a cada segundo.

- La acción es un `FieldActionButton` de 64dp y ancho completo: se pulsa con guantes
  sobre un techo, que es la razón por la que esa altura existe (ADR-0009).
- Un botón sólido por pantalla. "Marcar entrada" y "Marcar salida" nunca conviven.
- Las banderas van con `StatusChip` en `warningContainer`, con su icono. Nunca color
  solo, nunca relleno sólido — compiten con la acción.
- `CONFLICT` va en `dangerContainer` y dice qué pasó y que lo va a revisar alguien. Un
  estado que no se explica se lee como un error de la app.
- Sin asignaciones para hoy, el estado vacío dice a quién pedirle una — no "sin datos".

**Mi semana** — las jornadas con sus horas, su estado y sus banderas. Solo lectura.
**No es un eje**: se abre desde Hoy con `push`. SPEC-0003 fijó que un `WORKER` ve
exactamente dos pestañas y que ningún rol ve más de cuatro, y ese criterio está
verificado — un eje nuevo lo rompería.

**La gente de la obra** (foreman) — no es una pantalla nueva: es el eje **Cuadrilla**
que SPEC-0003 ya le da al `FOREMAN` con `crews.read`, hasta hoy un placeholder.

Lo que muestra es **quién está asignado a la obra de hoy** —directo o por su
cuadrilla—, con quién ya marcó y quién no, y desde ahí se marca por alguien. La lista
es de la obra y no de la cuadrilla, porque ese es el criterio: quien fue ese día ficha
por quien también fue.

**Y se puede marcar por alguien que no está en la lista.** La bandera no es una puerta
cerrada: se busca a la persona, se marca, y queda señalado. Una pantalla que solo deje
elegir de la lista convierte la bandera en bloqueo por la puerta de atrás, y eso es lo
que la visión descartó.

## Criterios de aceptación

- [ ] Con el GPS denegado, marcar entrada **pide la foto**; con el GPS disponible, no
      la pide.
- [ ] Con el GPS y la cámara denegados, la entrada **se registra igual**, con
      `NO_LOCATION` y `NO_PHOTO`.
- [ ] Ninguna rama del marcaje puede terminar sin fila escrita: hay una prueba que
      deniega todos los permisos y corta la red, y la fila existe.
- [ ] El cronómetro arranca al instante y con la red caída, con `sync_status = PENDING`.
- [ ] Una entrada marcada sin señal llega al servidor **exactamente una vez** aunque
      se reintente.
- [ ] Marcar entrada dos veces deja la segunda fila en `CONFLICT` con
      `TIME_ENTRY_ALREADY_OPEN`, y **no se reintenta sola**. *(Cierra el criterio
      abierto de SPEC-0004.)*
- [ ] Marcar salida sobre un registro ya cerrado la deja en `CONFLICT` con
      `TIME_ENTRY_ALREADY_CLOSED`.
- [ ] Cualquier otro código de error deja la operación reintentable y **no** marca
      conflicto.
- [ ] La foto de respaldo tomada sin señal sube sola cuando vuelve la red, y su
      `media_asset` queda en `READY`.
- [ ] La cámara del marcaje se abre en captura directa: **no hay camino desde ahí a la
      galería del teléfono**, y el `media_asset` queda con su `capturedAt`.
- [ ] `openapi.json` declara la respuesta de `POST /media` y de la URL de subida con
      sus campos, y el cliente Dart las expone tipadas y no como `dynamic`.
- [x] Un `FOREMAN` **que está asignado a la obra ese día** —directo o por su
      cuadrilla— marca por otro: queda con `method = FOREMAN`,
      `recorded_by_membership_id` distinto de `membership_id`, y **sin** bandera.
      La condición es sobre quien marca; el destinatario no se evalúa.
- [x] Un `FOREMAN` **sin asignación en esa obra ese día** marca por otro: **se
      registra igual**, con `RECORDER_NOT_ASSIGNED` — también al cerrar la jornada
      de otro. No hay ninguna entrada que devuelva 403 por esto, y hay un caso en
      `edge-cases/` que lo afirma.
- [x] Con `project_assignment` vacío —que es el estado de hoy— nadie queda sin poder
      marcar: todos se registran, todos con la bandera.
- [x] Un `OWNER` que marca por otro queda con `method = ADMIN`, no `FOREMAN`.
- [x] Un `FOREMAN` que sincroniza **no** se baja clientes ni horas ajenas a sus obras,
      con su caso en `edge-cases/`.
- [x] `pay_rate_cents` no aparece en ninguna respuesta que baje al móvil.
- [ ] `is_mock_location` viaja en toda marca, y una entrada con GPS simulado en
      Android llega al servidor con su bandera.
- [ ] El servidor recalcula `within_geofence` y `distance_m`: una entrada que los
      manda desde el dispositivo los recibe ignorados.
- [x] Un `FOREMAN` que sincroniza **recibe** su cuadrilla, sus miembros vigentes y el
      nombre de cada uno: la pantalla muestra personas y no UUIDs.
- [ ] Un `WORKER` ve la dirección de la obra de hoy y la abre en la app de mapas del
      teléfono, **sin pasar por ninguna pantalla de clientes** — no tiene permiso para
      esas.
- [ ] Ninguna pantalla de asistencia importa un cliente de `lib/api/` — lo verifica la
      prueba que ya recorre `lib/features/`.
- [ ] La pantalla se ve entera en claro y en oscuro, y ningún label se corta en
      español.
- [ ] Cero cadenas quemadas: todo el copy nuevo —banderas, `CONFLICT`, estados vacíos,
      el texto de cada bandera— existe en `en` y en `es`, agregado en el mismo commit.

## Riesgos / consideraciones

**Depende de SPEC-0007, que depende de un ADR que no existe.** Sin el punto de la
obra, `evaluateGeofence` devuelve `within = null` y la geocerca no evalúa nada — lo
que el propio SPEC-0007 llama *"la geocerca es teatro"*. El orden es: ADR de proveedor
de mapas → SPEC-0007 → este. Implementar antes deja la mitad de los criterios sin
poder verificarse.

**La alerta al llegar a la obra roza el gate de la visión.** *"No hacemos tracking
continuo de ubicación"*. El monitoreo de regiones no traza rutas —el sistema avisa al
cruzar el borde y la app no ve nada más—, pero **el permiso que exige es "Siempre"**, y
eso es lo que la persona percibe. Un trabajador incómodo con una foto de la pared que
pintó va a estar más incómodo con que la app sepa dónde está con el teléfono guardado.
Cuando se escriba ese spec, la pantalla que explica el permiso es la mitad del trabajo.

**`is_mock_location` es Android y nada más.** iOS no expone si la ubicación viene de
un simulador. Se manda `false`, y `false` acá significa *"no se pudo saber"*, no
*"verificado"*. Quien lea la bandera en un reporte tiene que saberlo, o la va a leer
como una garantía que no es.

**Dependencias nuevas.** `geolocator` para el punto y el `isMocked` de Android;
`camera` o `image_picker` para la foto; `crypto` para el checksum que desduplica los
reintentos de subida. Las tres se justifican en el PR y ninguna es opcional: sin GPS
no hay evidencia, sin cámara no hay respaldo, y sin checksum un reintento duplica el
asset.

**William es `OWNER` y no ve la pestaña Hoy.** `_byRole` no se la da, y `time.clock`
sí lo incluye. Para una demo donde él marca en su propio teléfono, hay que decidir si
la ve — es decisión de producto y no se resuelve al implementar.

**El consentimiento de ubicación sigue sin firmarse.** `DECISIONES.md` lo tiene
abierto y ADR-0003 lo cita como mitigación no resuelta: *"registrar GPS de empleados
requiere consentimiento informado y por escrito"*. **Este es el primer spec que
efectivamente captura la ubicación de un trabajador**, así que deja de ser un pendiente
teórico. No bloquea implementar —bloquea usarlo con gente real— y hay que decidir
dónde vive: onboarding, primera apertura de la app, o fuera del software.

**El tope de espera del GPS es el número que decide si esto se usa.** Muy corto y
ninguna marca tiene coordenadas; muy largo y el trabajador cree que la app se colgó.
Empieza en 10 segundos y se ajusta con William en la obra, no en una reunión.

## ADRs relacionados

- [[../../../adr/0003-asistencia-geocerca-foto/README|ADR-0003]] — la decisión de
  fondo: evidencia sin bloquear. Este spec le agrega **cuándo** se pide la foto, que el
  ADR dejó sin escribir.
- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]] — Drift y la arquitectura
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — los 64dp de la
  acción de campo, que es exactamente este botón
- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — por qué el `{}` de
  `POST /media` es un problema de contrato y no un detalle

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-11 | en implementación | **Verificado contra la base viva**: 27 comprobaciones por API real —los dos pulls acotados, la bandera en obra ajena y su ausencia en la propia, `method` por rol, cero tarifas en ningún cuerpo, y media tipado— todas en verde. Los siete criterios del API quedan en `[x]`; los del móvil esperan la tanda 2. De paso quedó verificado que la bandera **sobrevive al cierre** de la jornada. |
| 2026-08-11 | en implementación | Primera tanda terminada: los siete prerequisitos del API, revisados con `domain-guardian`, `contract-watcher` y `code-reviewer`. El guardián encontró de paso una fuga real —`pay_rate_cents` bajaba embebido en cuadrillas y asignaciones, hasta un `WORKER` podía ver la tarifa de sus compañeros— cerrada con el patrón de `passwordHash`, también para el snapshot de `time_entry`. Del reviewer salieron la bandera en `clockOut`, la vigencia en la visibilidad de cuadrillas y los edge-cases que faltaban o no afirmaban nada. **Los criterios no se marcan todavía**: los casos de Bruno están escritos pero sin correr contra la base —Docker apagado—, y marcar con la verificación pendiente es el error que SPEC-0004 ya pagó una vez. Se corren antes del merge. |
| 2026-08-11 | en implementación | Primera tanda: los siete prerequisitos de `apps/api`, que bloquean todo lo del móvil. |
| 2026-08-11 | aprobado | Su único bloqueo era SPEC-0007, mergeado en el PR #12: la geocerca ya tiene punto contra el cual evaluar. `geolocator` quedó instalado y heredado, como ADR-0012 había previsto. |
| 2026-08-10 | review | Entra al alcance **ver a dónde ir**: la obra de hoy muestra su dirección y su punto y se abre en la app de mapas. Sale de revisar SPEC-0007, que prometía eso en su `goal` y no podía cumplirlo — su pantalla está detrás de `customers.read` y un `WORKER` nunca llega. "Hoy" es la única pantalla que ese rol abre, así que el dato se muestra acá. |
| 2026-08-10 | borrador | Revisado con `spec-reviewer`, que encontró **una contradicción con la visión**: `vision.md` ya había decidido ese mismo día quién ficha por otro, y con otro criterio —la obra y no la cuadrilla, aplicado como bandera y no como bloqueo—, cerrando su argumento en que `time.approve` sigue siendo de `OWNER`/`ADMIN`. La primera versión de este spec lo había resuelto por cuadrilla y con el foreman aprobando, que es exactamente lo que ese texto descarta por nombre. **Gana la visión**: se reescribieron el prerequisito 0, el alcance, la UI y los criterios; la aprobación en el móvil salió del alcance. Del mismo repaso salieron el estado `READY` que el criterio de la foto citaba mal como `uploaded`, el contrato de API con sus shapes, y que `method` dice `FOREMAN` aunque marque el dueño. |
| 2026-08-10 | borrador | Descartado apoyarse en los metadatos de la foto para la ubicación: el GPS del EXIF sale del mismo permiso ya denegado, se edita con cualquier app, y `markUploaded()` borra el EXIF a propósito para no publicar la casa de un cliente con sus coordenadas. Lo que queda es `capturedAt` contra la foto de galería, y se resuelve abriendo la cámara en captura directa. |
| 2026-08-10 | borrador | Creado. Sale de que SPEC-0004 tiene dos criterios que solo el marcaje puede cerrar. La decisión de producto del spec es **la escalera de evidencia**: el GPS es la prueba y la foto es lo que queda cuando no hay GPS, así que a nadie se le pide una foto por defecto. Descartado el selfie —vigila a la persona y no aporta contenido— y descartada la alerta por geocerca en este alcance, que exige el permiso "Siempre" y va en su propio spec. Seis prerequisitos de contrato encontrados verificando el código: el foreman no puede aprobar, el `WORKER` no puede leer sus horas, el pull no baja cuadrillas, su scope por rol deja afuera al `FOREMAN`, `POST /media` sale como `{}` y no hay forma de pedir la URL de subida de un asset registrado por la bandeja. |
