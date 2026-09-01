---
id: SPEC-0011
title: "Horas de la obra"
aliases:
  - "SPEC-0011: Horas de la obra"
type: spec
platform: mobile
status: en implementación
goal: "William abre una obra y ve cuántas horas lleva en total y cada jornada con quién la hizo; aprueba o rechaza una jornada desde ahí, también sin señal, y una decisión tomada sobre un estado que ya cambió nunca se aplica sola."
apps:
  - mobile
  - api
depends_on:
  - "0004-capa-local-y-sincronizacion"
  - "0008-asistencia-en-el-movil"
  - "0009-la-obra-como-lugar"
domain:
  - registro-de-tiempo
  - proyecto
frente: administrativo
created: 2026-08-31
updated: 2026-08-31
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0011: Horas de la obra

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0008-asistencia-en-el-movil/README|SPEC-0008]], [[../0009-la-obra-como-lugar/README|SPEC-0009]]
> - Frente: `administrativo`

---

## Problema

Las horas se registran desde SPEC-0008 y **nadie las mira**. El eje que las
recoge existe; el que las cierra, no.

Hoy cada rol ve un pedazo y ninguno ve la obra:

| Quién | Qué ve | Dónde |
|---|---|---|
| `WORKER` | Sus jornadas en la obra donde está asignado | Tab Registro (SPEC-0009) |
| `FOREMAN` | El acumulado semanal de su cuadrilla, **y subestimado** — solo baja lo de las obras donde él está asignado | Tab Horas de la cuadrilla (SPEC-0009) |
| `OWNER` / `ADMIN` | Nada. La tab Horas de la obra es `PlaceholderList` desde SPEC-0003 | — |

Justo el rol que responde por el dinero es el que no tiene la vista. Y del brief
comercial, en la columna de lo **validado**: *dos cuadrillas, sin control de horas
ni asistencia, y todo se junta a mano para el contador.* La app hoy resuelve la
mitad de eso — captura y no consolida.

Aprobar está peor: `POST /time-entries/:id/approve` y `/reject` existen desde
SPEC-0008 y **ninguna pantalla los llama**. La regla 13 dice que la tarifa se
congela al aprobar, y hasta que alguien apruebe, ninguna hora de este sistema
tiene tarifa congelada. Sin ese acto no hay timesheet, y sin timesheet el frente
de reportes no tiene de dónde salir.

## Alcance

### Entra

**La tab Horas de `ProjectScreen`, que hoy es placeholder.** En la práctica la
usan `OWNER` y `ADMIN`: `projects` no está entre los ejes del `FOREMAN` ni del
`WORKER` (`app_destination.dart`), que entran a la obra por `ObraScreen` con sus
propias tabs. **Esas pantallas no se tocan.**

> Eso es una garantía de navegación, **no de acceso**: `Routes.project` cuelga
> del `_rootNavigatorKey` y no del shell que filtra por rol
> (`app_router.dart`), y el tab se gatea con `time.read`, que todos los roles
> tienen (`permissions.ts`). La condición dura la ponen los permisos de cada
> acción, no quién llega a la pantalla — por eso los botones de decidir se
> gatean aparte con `time.approve`. Es preexistente y vale igual para Avance,
> Fotos y Detalle; se anota para no apoyarse en una garantía que no existe.

- **Un encabezado con lo que la obra lleva acumulado**: horas totales, cuántas
  personas la trabajaron, cuántas jornadas y **cuántas están sin aprobar**. Ese
  último número es el que convierte la pantalla en una bandeja de trabajo y no
  en un dato de adorno.
- **Debajo, las jornadas en orden cronológico**, más recientes primero,
  agrupadas por día. Cada fila: quién, entrada, salida, total y su estado.
  **No se agrupa por persona** — la pregunta que se contesta acá es "qué pasó en
  esta obra", y por persona es la vista de la cuadrilla, que ya existe.
- **Expandir una jornada muestra su detalle**: banderas con su etiqueta legible
  (las de `flag_labels.dart`, ya traducidas), quién marcó si no fue la propia
  persona, si se registró sin señal, y **la razón de la decisión** cuando fue
  rechazada.
- **Aprobar y rechazar, por jornada**, para quien tenga `time.approve`
  (`OWNER` y `ADMIN`). Rechazar pide una razón — `ApproveDto.reason` ya existe y
  hoy viaja vacío; es lo único que explica por qué un día no cuenta.
- **Las dos acciones funcionan sin señal.** Se escribe el estado en local, se
  encola y se sincroniza. Esto obliga a **dos operaciones nuevas en
  `SYNC_OPERATIONS`**, a que la operación viaje con el estado que el dispositivo
  vio, y a un camino de resultado que el sincronizador hoy no tiene — ver
  Contrato de API y Comportamiento sin señal.
- **El botón no aparece donde el servidor va a decir que no**: sobre las horas
  propias (`CANNOT_APPROVE_OWN_HOURS`, y aplica al `OWNER` igual que a
  cualquiera) ni sobre una jornada todavía abierta. Prevenir acá es distinto de
  bloquear el marcaje: nadie deja de fichar porque no se le ofrezca aprobarse a
  sí mismo.

### No entra

- **Editar horas a mano.** Corregir una entrada o una salida es escritura sobre
  el agregado más delicado del sistema, exige rastro en `time_entry_edit`
  (regla 12) y merece su propio spec. Aprobar y rechazar ya dejan ese rastro
  porque el servidor los registra; cambiar valores es otra cosa.
- **Aprobar en lote.** "Aprobar todo" es el atajo obvio y por eso hay que
  nombrarlo para dejarlo afuera: multiplica por N un acto que congela tarifas, y
  sin señal multiplica también los rechazos diferidos. Cuando se quiera, con su
  spec y su confirmación.
- **Dinero.** `pay_rate_cents` va con `select: false` en la entity y
  `@ApiHideProperty` en el contrato: **la tarifa no baja al teléfono y esta
  pantalla no la muestra**. Horas, no dólares. El costo por proyecto es del
  frente `reportes`.
- **El historial completo de correcciones.** `time_entry_edit` no baja al
  teléfono y sigue sin bajar: es auditoría, crece sin techo y su lugar de
  consulta es la web. Lo que baja es la **última** decisión, no el rastro.
- **El timesheet exportable para el contador.** Frente `reportes`, y es de la
  web.
- **La tab Avance**, que va en su propio spec y después de este.
- **Cambiar lo que ven el trabajador y el foreman.** El tab Registro y el tab
  Horas de la cuadrilla quedan como están.

## Modelo de dominio afectado

- [[../../../domain/registro-de-tiempo|Registro de Tiempo]]
- [[../../../domain/proyecto|Proyecto]]

Ningún agregado nuevo. **Una columna nueva**, y hay que decir por qué:

### `time_entry.decision_reason`

`approved_by_membership_id` y `approved_at` ya se escriben en las **dos**
decisiones —aprobar y rechazar— y guardan quién decidió y cuándo. Falta el
porqué: hoy la razón se escribe solo en `time_entry_edit`
(`time-entries.service.ts`), una tabla sin controller que el pull no baja. La
pantalla no tenía de dónde sacarla.

`decision_reason` completa el trío quién / cuándo / por qué sobre la jornada
misma.

- **No debilita la regla 12.** El rastro completo sigue intacto en
  `time_entry_edit`, con valor anterior y todo; esto es una proyección de
  lectura de la última decisión, no su reemplazo. Si una jornada se rechaza y
  después se aprueba, la columna muestra la última y la auditoría muestra las
  dos.
- Va también a la ficha `docs/domain/registro-de-tiempo.md`, en la tabla de
  atributos.
- **Pasa por `domain-guardian` antes de escribir la migración** (regla 28).

Las reglas del dominio que este spec toca de cerca:

| Regla | Cómo la respeta |
|---|---|
| **12** — las horas no se borran ni se sobrescriben | El móvil nunca escribe `status` en el servidor por su cuenta: manda la operación con el estado que vio y el servidor decide y registra el `time_entry_edit`. Un conflicto se marca y espera a un humano |
| **13** — la tarifa se congela al aprobar | La congela el servidor al aplicar, con la tarifa que él tiene. El móvil no la conoce ni la manda — ver Riesgos |
| **19** — escrituras idempotentes | La operación viaja con su `clientId` UUIDv7, que no cambia entre reintentos |
| **7** — default deny | Las dos operaciones declaran `time.approve` en `OPERATION_PERMISSION`. Sin eso, un `WORKER` aprobaría dentro del lote lo que la puerta REST le niega |
| **10** — dos marcas de tiempo | No se tocan. `decision_reason` acompaña a `approved_at`, que es hora de servidor |

## Comportamiento sin señal

**Leer es local siempre.** Para `OWNER` y `ADMIN` el pull **no está acotado**
(`sync.service.ts`: `acotado` es solo `WORKER` y `FOREMAN`), así que las
`time_entry` de la obra bajan completas y la pantalla no necesita
`GET /time-entries` ni ninguna otra lectura de red. Consistente con toda la app:
las pantallas leen Drift y no saben si hay señal.

**Escribir tampoco espera.** Aprobar o rechazar escribe el estado en local, deja
la fila en `pending` y encola. La pantalla responde al instante.

### La decisión viaja con el estado que se vio

Es la pieza que hace todo lo demás posible. La operación encolada lleva
`expectedStatus`: **el estado que la jornada tenía en el teléfono cuando la
persona decidió.** El servidor compara contra el actual antes de aplicar.

Sin eso no hay forma de distinguir los dos casos que importan, porque los dos
llegan como "esta jornada ya no está en `PENDING`":

- El `OWNER` ve *Rechazada*, entiende que fue un error y toca **Aprobar**. Es
  una corrección deliberada y tiene que aplicarse: manda
  `expectedStatus: REJECTED`, el servidor coincide, aplica.
- El `OWNER` ve *Pendiente*, aprueba sin señal, y mientras tanto un `ADMIN`
  rechazó desde la web. Manda `expectedStatus: PENDING`, el servidor tiene
  `REJECTED`: **dos personas decidieron distinto sobre las mismas horas**, y eso
  no se resuelve solo.

El mismo mecanismo cubre las dos direcciones — aprobar sobre rechazado y
rechazar sobre aprobado — sin que el móvil tenga que adivinar nada.

### Qué hace el móvil con cada respuesta

| Lo que responde el servidor | Qué pasó de verdad | Qué hace el móvil |
|---|---|---|
| Aplicada | Todo bien | Sale de la cola, la fila queda `synced` |
| `TIME_ENTRY_DECISION_MATCHES` | El estado actual ya **es** el que se pidió: alguien decidió lo mismo desde otro lado | **Benigno.** El estado local ya coincide con el del servidor. **Descarte**: sale de la cola sin marcar nada |
| `TIME_ENTRY_DECISION_CONFLICTS` | El estado actual no es el que el dispositivo vio, y la decisión pedida es otra | **Conflicto** (regla 12): `syncStatus = conflict`, la operación no se reenvía y la fila espera a un humano |
| `PAY_RATE_MISSING` | La persona no tiene tarifa cargada. **El móvil no lo puede prevenir**: la tarifa no baja al teléfono, a propósito | **Descarte con reversión.** Sale de la cola, el estado local vuelve al que tenía antes de decidir y la fila queda con el motivo visible. **No es conflicto** — no hay dos verdades, hay un dato que falta |
| `TIME_ENTRY_STILL_OPEN` | La salida no había llegado al teléfono cuando se aprobó | Igual: descarte con reversión y motivo visible. Se decide de nuevo cuando la salida sincronice |
| `CANNOT_APPROVE_OWN_HOURS` | Bug del móvil: el botón no debió ofrecerse | Descarte con reversión, sin aviso al usuario — no es su problema. Queda en el log |
| Error de red, 5xx, cualquier otro | Nada, todavía | Se reintenta en la próxima corrida, como cualquier operación |

**Reintentar no es una opción para los cuatro del medio**: la causa está del
lado del servidor y reenviar lo mismo falla igual, para siempre. Por eso se
descartan; volver a decidir es un acto de la persona, con el estado nuevo a la
vista.

**Revertir se hace con el valor local, no pidiéndoselo al servidor.** Los cuatro
rechazos ocurren *antes* de cualquier escritura, así que `updated_at` no se mueve
y el pull incremental **no vuelve a traer esa fila**: esperar a que el servidor
la corrija deja la jornada mostrando "Aprobada" para siempre. El estado anterior
se guarda al escribir la decisión optimista y se restituye desde ahí.

### Lo que hay que construir para que eso sea cierto

El sincronizador de hoy tiene **dos** desenlaces y ninguno de los dos sirve:
aplicada sale de la cola (`synchronizer.dart`, `_aplicarResultados`), y fallida
se queda y se reintenta en cada corrida — salvo que esté en `conflictCodes`, que
la congela pero **tampoco la saca**. No existe descartar, ni revertir un valor
local escrito de forma optimista, ni guardar un motivo legible por fila.

Entra en el alcance de este spec:

| Dónde | Qué |
|---|---|
| `Synchronizer` | Una tercera categoría junto a `conflictCodes` — los códigos que **descartan**: sacan de la cola y revierten el estado local al del servidor |
| `Synchronizer.conflictCodes` | Suma `TIME_ENTRY_DECISION_CONFLICTS`. **Solo ese**: los demás son estado local corregido, no divergencia |
| Tabla `TimeEntries` (Drift) | `decisionReason` (baja del servidor), `recordedOffline` (ver abajo) y `lastRejection` — el **código** del último rechazo del servidor y el estado previo a revertir. Guarda el código, no el texto: se traduce en la capa de presentación, como ya hace `flagLabel()` con las banderas (regla 24). Local puro, no viaja a ningún lado |
| `SyncMapper.timeEntry` | Hoy no mapea `recordedOffline` ni `decisionReason`; el primero **ya viene en el DTO** y la tabla local no tiene dónde ponerlo. Sin eso, "se registró sin señal" no tiene de dónde salir |

## Flujo de usuario

1. William abre una obra desde el eje Obras y toca **Horas**.
2. Ve el encabezado: *"57:00 hs · 3 personas · 12 jornadas · 4 sin aprobar"*.
3. Baja por los días. Una jornada de María tiene la bandera de fuera de geocerca;
   la toca y se expande: entró 7:02, salió 15:40, 8:38 en total, fuera de la
   geocerca en la salida, marcada por ella misma.
4. Toca **Aprobar**. La fila pasa a aprobada al instante y el contador del
   encabezado baja a 3.
5. En otra jornada toca **Rechazar**; se le pide la razón, la escribe y confirma.
   La razón queda visible en la fila.
6. Estaba sin señal. Las dos operaciones esperan en la cola; al volver la red se
   aplican y el servidor congela la tarifa de la aprobada.
7. Si el servidor rechaza alguna, la fila vuelve al estado real y dice por qué.
   Y si dos personas decidieron distinto, queda marcada como conflicto y nadie
   la resuelve sola.

## Contrato de API

**Ningún endpoint nuevo.** `POST /time-entries/:id/approve` y `/reject` ya
existen con `time.approve`. Lo que falta es que se puedan **encolar**, que la
decisión diga sobre qué estado se tomó, y que la razón llegue al cliente.

### 1. Dos operaciones nuevas en el lote

```ts
// apps/api/src/sync/dto/sync.dto.ts
export const SYNC_OPERATIONS = [
  // …
  'timeEntry.clockIn',
  'timeEntry.clockOut',
  'timeEntry.approve',
  'timeEntry.reject',
] as const;

export const OPERATION_PERMISSION = {
  // …
  'timeEntry.approve': 'time.approve',
  'timeEntry.reject': 'time.approve',
} as const satisfies Record<SyncOperationType, Permission>;
```

El `id` de la jornada viaja en `targetId`. El payload es un DTO nuevo que
extiende el que ya existe:

```ts
export class SyncDecisionDto extends ApproveDto {
  // El estado que la jornada tenía en el dispositivo cuando se decidió.
  @IsEnum(TIME_ENTRY_STATUS) expectedStatus!: TimeEntryStatus;
}
```

El `satisfies` de `PAYLOAD_DTO` obliga a declararlo: una operación sin su DTO no
compila. Del lado del móvil, las dos constantes correspondientes en `SyncOp`.

### 2. `expectedStatus` opcional en el endpoint REST

`approve()` y `reject()` aceptan `expectedStatus` **opcional** en `ApproveDto`.
La web es online y no lo necesita: si no viene, se aplica el comportamiento de
hoy más la validación del punto 3. Si viene y no coincide con el estado actual,
se rechaza con código. Un solo camino en el servicio, dos clientes contentos.

### 3. `approve()` y `reject()` validan el estado actual

Hoy **ninguno de los dos** lo hace bien:

- `approve()` solo compara contra `APPROVED` (`time-entries.service.ts`). Sobre
  una jornada `REJECTED` se aplica en silencio — el conflicto que este spec
  describe en su propia tabla, hoy pasa sin que nadie se entere.
- `reject()` no compara contra nada: rechaza una ya aprobada sin decir palabra.
  Deja rastro en `time_entry_edit`, así que no rompe la regla 12 — pero desde la
  cola es exactamente el silencio que el cliente necesita ver.

La regla queda una sola, para los dos:

| Situación | Código | Status |
|---|---|---|
| El estado actual ya es el que se pide | `TIME_ENTRY_DECISION_MATCHES` | 409 |
| Vino `expectedStatus` y no coincide con el actual | `TIME_ENTRY_DECISION_CONFLICTS` | 409 |
| La jornada no tiene salida (solo aprobar) | `TIME_ENTRY_STILL_OPEN` | 400 |

Los nombres son neutrales a propósito: dos `ADMIN` rechazando la misma jornada
sin señal es igual de "ya decidido" que dos aprobándola, y un código llamado
`ALREADY_APPROVED` sobre algo que nunca se aprobó ensucia los logs y engaña a
quien lo lea después.

**La comparación y la escritura tienen que ser un solo acto.** Hoy el servicio
lee con un `SELECT` simple, valida contra `entry.status`, consulta la tarifa —
otra ida a la base en el medio— y recién ahí escribe un
`UPDATE ... WHERE id = $1` que **no condiciona por el estado que leyó**. Sin
`isolationLevel` declarado, eso corre en `READ COMMITTED`: dos decisiones casi
simultáneas pueden leer las dos el mismo estado viejo, pasar las dos la
validación, y la segunda pisar en silencio a la primera. Sería el mismo "se
resuelve solo" que este mecanismo existe para impedir, ahora escondido en una
ventana de milisegundos.

El `UPDATE` condiciona por el estado leído y **cero filas afectadas es
`TIME_ENTRY_DECISION_CONFLICTS`**:

```sql
UPDATE time_entry SET status = $2, ... WHERE id = $1 AND status = $3
```

Se prefiere al `SELECT ... FOR UPDATE` porque no sostiene un lock mientras se
consulta la tarifa, y porque deja la garantía en la base y no en el orden de las
líneas del servicio.

**Es el patrón que este agregado ya usa.** "Una sola jornada abierta por
persona" no se confía a la comprobación de `time-entries.service.ts`: la
garantiza `uq_time_entry_single_open` (migración `IndexesAndInvariants`), y el
choque llega al cliente como `TIME_ENTRY_ALREADY_OPEN` porque el filtro de
excepciones lo mapea (regla 8). Acá vale lo mismo: **`expectedStatus` es la
regla de negocio; la condición del `UPDATE` es lo que la vuelve verdad.**

`PAY_RATE_MISSING` y `CANNOT_APPROVE_OWN_HOURS` ya existen con su código y no
cambian.

### 4. `decision_reason` en `time_entry`

Columna `text`, nullable, con su migración en
`apps/api/src/database/migrations/`. La escriben `approve()` y `reject()` con el
`reason` que ya reciben, en la misma transacción que el `time_entry_edit`. Viaja
en la entity y por lo tanto en el pull, sin trabajo extra.

### 5. `openapi.json` regenerado

`pnpm contracts:generate` es parte de terminar esto (regla 8), y de ahí salen
los modelos Dart de las operaciones y el campo nuevos.

## UI

Una sola pantalla, `HoursTab`, reemplazando `PlaceholderList` en
`project_screen.dart`.

```
┌─ Horas en esta obra ─────────────┐   ← SectionCard, banda arriba
│  57:00 hs · 3 personas           │
│  12 jornadas · 4 sin aprobar     │
└──────────────────────────────────┘

┌─ Viernes 29 de agosto ───────────┐
│ María González      7:02–15:40   │
│ 8:38 · ⚑ Fuera de geocerca       │
│ ● Sin aprobar     [Rechazar][Aprobar]
├──────────────────────────────────┤
│ Juan Ramírez        7:15–15:40   │
│ 8:25 · ● Aprobada                │
└──────────────────────────────────┘
```

Piezas y reglas que ya existen y se reusan tal cual: `SectionCard` para las
secciones con su banda, `StatusChip` para el estado, `flag_labels.dart` para las
banderas, `StatusLine`, y el patrón colapsable del tab Registro.

- **Las acciones dicen qué hacen, con palabras.** "Aprobar" y "Rechazar", nunca
  un ✓ y una ✗ que haya que adivinar (SPEC-0009).
- **El estado a la izquierda, las acciones a la derecha**, sin competir por el
  mismo peso.
- **Rechazar confirma y pide razón; aprobar no confirma.** Asimétrico a
  propósito: rechazar es lo que le saca el día a alguien.
- **La razón se muestra en la jornada rechazada**, que es para lo que existe
  `decision_reason`.
- **Un rechazo del servidor se ve en su fila**, con el motivo y sin tono de
  error de sistema: la jornada volvió a estar sin aprobar y hay algo que hacer.
- Cero cadenas quemadas en `en` y `es`, los dos temas, ningún valor de estilo
  literal, y **horas y fechas formateadas por la capa de i18n** (regla 24).

## Criterios de aceptación

- [x] La tab Horas de `ProjectScreen` deja de ser `PlaceholderList` y muestra
      el encabezado con horas totales, personas, jornadas y cuántas sin aprobar,
      todo sobre **toda la vida de la obra**, no una ventana de 7 días.
- [x] Debajo, las jornadas de la obra agrupadas por día, más recientes primero,
      cada una con persona, entrada, salida y total; expandida muestra banderas,
      quién marcó, si fue sin señal y la razón si fue rechazada.
- [x] Una jornada abierta se muestra con el reloj corriendo y **no ofrece
      aprobar**.
- [x] Quien tiene `time.approve` ve los botones; el resto ve solo el estado. El
      botón **no aparece sobre las horas propias**, ni para el `OWNER`.
- [x] Rechazar pide razón, la guarda en `decision_reason`, y la razón se ve en
      la jornada rechazada después de sincronizar — incluso en otro dispositivo.
- [x] Aprobar y rechazar sin señal dejan la fila con el estado nuevo en local y
      la operación en la cola; al volver la red se aplican y el servidor congela
      la tarifa.
- [x] `SYNC_OPERATIONS` acepta `timeEntry.approve` y `timeEntry.reject`, ambas
      con `time.approve` en `OPERATION_PERMISSION`, y un `WORKER` que las mande
      en el lote recibe 403 — con test.
- [x] Aprobar dos veces la misma jornada con el mismo `clientId` no produce dos
      `time_entry_edit`: el servidor responde `duplicate` (regla 19). Lo resuelve
      el mecanismo de idempotencia de SPEC-0004, que la decisión usa sin cambios
      —`enqueue` fija el `clientId` y no lo mueve entre reintentos—; cubierto por
      los tests de `outbox`, no por uno propio de esta feature.
- [x] `approve()` sobre una jornada `REJECTED` **no se aplica en silencio**:
      responde `TIME_ENTRY_DECISION_CONFLICTS` si el `expectedStatus` no
      coincide, y aplica si coincide (la corrección deliberada). Lo mismo
      `reject()` sobre una `APPROVED`. **Test verificado contra el código sin el
      arreglo, en las dos direcciones.**
- [x] `TIME_ENTRY_DECISION_MATCHES` saca la operación de la cola sin marcar
      nada; `TIME_ENTRY_DECISION_CONFLICTS` deja la fila en `conflict` y no se
      reenvía.
- [x] La escritura de la decisión condiciona por el estado leído
      (`UPDATE ... WHERE id = $1 AND status = $2`) y **cero filas afectadas
      responde `TIME_ENTRY_DECISION_CONFLICTS`**. Implementado en
      `applyDecision`, con el `recordEdit` después del chequeo — sin eso, un
      choque dejaría auditado un cambio que no ocurrió.
      **Sin test de concurrencia real**: exige dos transacciones simultáneas
      contra Postgres y la suite del API es unitaria. La garantía la da el
      `WHERE`, no una comprobación de aplicación; el caso de estado viejo sí
      queda en `requests/edge-cases/decidir-sobre-un-estado-viejo.bru`.
      **Ver Riesgos.**
- [x] `PAY_RATE_MISSING`, `TIME_ENTRY_STILL_OPEN` y `CANNOT_APPROVE_OWN_HOURS`
      **sacan la operación de la cola** —no se reintentan— y devuelven el estado
      local al que tenía antes de decidir; los dos primeros dejan el motivo
      visible en la fila. Con test de que la cola queda vacía, el estado
      revertido **sin depender de un pull**, y el motivo traducido desde su
      código.
- [x] `SyncMapper.timeEntry` mapea `recordedOffline` y `decisionReason`, con sus
      columnas en `TimeEntries`.
- [x] `docs/domain/registro-de-tiempo.md` incluye `decision_reason` en su tabla
      de atributos, y `domain-guardian` revisó la columna antes de la migración.
- [x] `openapi.json` regenerado y los modelos Dart al día.
- [x] Cero cadenas quemadas en `en` y `es`; ambos temas; ningún valor de estilo
      literal; horas y fechas por la capa de i18n.

## Riesgos / consideraciones

- **La tarifa se congela cuando el servidor aplica, no cuando William tocó.**
  Aprobar el martes sin señal y sincronizar el jueves congela la tarifa del
  jueves. Es el comportamiento correcto y no una concesión: el móvil **no
  conoce** `pay_rate_cents` —va con `select: false` y `@ApiHideProperty`— y un
  teléfono que mandara la tarifa a congelar es exactamente lo que la regla 13
  previene. La ventana de exposición es la del retraso de sincronización, y el
  rastro del cambio de tarifa queda del lado de la oficina. **Se acepta y se
  documenta; no se mitiga en el móvil.**
- **`PAY_RATE_MISSING` es un rechazo que solo se descubre al sincronizar.** Es
  el precio de no bajar la tarifa al teléfono, y se paga a conciencia. La
  mitigación es que la fila nombre el motivo y la persona, para que se sepa qué
  cargar en la web.
- **El descarte es nuevo y hay que tratarlo con cuidado.** Hasta hoy ninguna
  operación salía de la cola sin haberse aplicado; una regla mal escrita
  descarta trabajo real de una persona en silencio. Por eso la lista de códigos
  que descartan es **explícita y cerrada**, como `conflictCodes`: todo lo demás
  se reintenta. Un código desconocido nunca descarta.
- **Aprobar es irreversible en el sentido que importa.** No hay desaprobar: una
  aprobación se corrige rechazando, con razón, y un rechazo se corrige
  aprobando, también con razón. Los dos dejan su `time_entry_edit`. Por eso
  rechazar confirma y aprobar no: el que necesita fricción es el que le saca el
  día a alguien.
- **El pull del `OWNER` no está acotado.** Bajan todas las `time_entry` de la
  empresa, no las de esta obra. Hoy con datos de demo no se nota; con un año de
  dos cuadrillas es un espejo local grande en un teléfono, y **lo que baja queda
  en disco**. Este spec lo hereda de SPEC-0004, no lo introduce, pero es la
  primera pantalla que hace ese volumen visible. Si el filtrado por obra sobre
  Drift se siente lento con datos reales, es `/debt-new`, no un cambio de
  alcance acá.
- **La bandeja de trabajo puede quedar vacía y hay que decirlo bien.** Una obra
  recién creada no tiene jornadas: el estado vacío explica que todavía nadie
  marcó, no muestra un cero suelto.
- **Es la primera escritura de la app que un tercero puede haber hecho antes.**
  Todo lo anterior que se encola lo origina el mismo dispositivo; aprobar
  compite con la web y con otro teléfono. De ahí `expectedStatus`: sin él, la
  única salida honesta sería marcar conflicto siempre, y el caso benigno —los
  dos decidieron lo mismo— es el frecuente.
- **Decidir toma el turno de la bandeja, y es la única espera de la app.** El
  resto de las escrituras responde al instante y sincroniza después; acá la
  escritura local también hace cola detrás de un push en vuelo. La razón:
  `decidedFrom` sale de `status`, y `status` solo dice lo que el servidor tiene
  hasta que ese push lo confirma. Leerlo en el medio deja la decisión pidiendo
  un estado viejo. Lo que se espera es un push, no una red —sin señal falla
  enseguida—, y esto es aprobar, que es de oficina: el marcaje que la regla 9
  protege no pasa por acá.
- **El turno es de la bandeja entera, no de la jornada.** Decidir sobre una obra
  espera un push que puede estar mandando un cliente de otra. Es más ancho de lo
  que hace falta para cerrar la carrera, y se acepta así: el timeout de red lo
  acota (10s de conexión, 20s de lectura) y partir el candado por `targetId`
  agrega estado que hay que mantener correcto justo donde no se puede improvisar.
  Si alguna vez se siente, se angosta — no antes.
- **Una sola decisión pendiente por jornada, y no es un detalle.** Cambiar de
  opinión sin señal —rechazar y corregir aprobando, que es el camino que la
  pantalla habilita— **sustituye** la operación encolada en vez de agregar otra.
  Con las dos en la cola, el servidor aplicaba la primera y rechazaba la segunda
  por no coincidir con el estado que él mismo acababa de cambiar: la jornada
  terminaba con la decisión **descartada**, marcada en conflicto, sin que nadie
  más hubiera decidido nada. `expectedStatus` protege del choque entre personas;
  esto protege del choque de alguien consigo mismo.
- **La atomicidad quedó sin test que la ejercite.** El `UPDATE ... WHERE status`
  es correcto y el `recordEdit` va después de comprobar `affected`, pero nada
  automatizado prueba dos escrituras simultáneas: haría falta levantar dos
  transacciones contra Postgres, y la suite del API es unitaria. Es el riesgo
  residual conocido de este spec — si alguna vez se ve un `time_entry_edit` sin
  cambio de estado detrás, es acá donde hay que mirar.
- **El patrón que sale de acá lo hereda Avance.** Escribir sin señal algo que
  el servidor puede rechazar por estado es el mismo problema que tiene crear un
  `project_update` offline. Resolverlo primero en horas, donde las reglas son
  más duras, deja el camino hecho para la tab siguiente.

## ADRs relacionados

- [[../../../adr/0003-asistencia-geocerca-foto/README|ADR-0003]] — la asistencia que produce lo que esta pantalla lee
- [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] — los códigos nuevos siguen su forma

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-31 | en implementación | Listo para PR. 78 tests del API y 347 del móvil. Tres pasadas del `code-reviewer`; las dos primeras encontraron GRAVE. Lo que salió de acá y vale más allá del spec: **el turno de la bandeja**, que vuelve atómico el ciclo armar-enviar-aplicar del push, y **`decision_reason`**, que le da a la jornada el porqué de su decisión y no solo el quién y el cuándo. La pantalla de conflictos ausente quedó en DEBT-0011 con el hueco del pull anotado ahí. |
| 2026-08-31 | en implementación | Segunda pasada del `code-reviewer`: sustituir en la cola no alcanzaba. Encolar dispara el push solo (`syncEngineProvider`), así que cuando la persona toca el segundo botón la primera decisión **ya viajó** — borrarla de la bandeja no la alcanza, y el resultado era el mismo: en el servidor quedaba la decisión descartada. Se cierra tomando el turno de la bandeja: armar el lote, esperar la red y aplicar la respuesta son un solo acto, y decidir espera ese turno. Es la única escritura de la app que espera, y el porqué está en Riesgos. La pantalla de conflictos ausente pasa a DEBT-0006. |
| 2026-08-31 | en implementación | Hallazgos del `code-reviewer`. **GRAVE**: dos decisiones encoladas sobre la misma jornada llevaban el mismo `expectedStatus`, así que el servidor aplicaba la primera y rechazaba la segunda — la jornada quedaba con la decisión que la persona descartó, en conflicto y sin salida desde la app. Se arregla sustituyendo la decisión pendiente (`Outbox.replacePending`) en vez de apilar otra. El test que lo cubre usa un fake que modela el estado del servidor entre operaciones del mismo lote; el anterior solo miraba el payload y por eso no lo veía. **MEDIO**: varias jornadas expandidas mostraban varios "Aprobar" en naranja sólido a la vez, contra la regla del naranja — ahora hay una sola fila abierta por lista. |
| 2026-08-31 | en implementación | Arranca por `domain-guardian` sobre `decision_reason`, que el spec puso como paso previo a la migración. |
| 2026-08-31 | aprobado | El `spec-reviewer` condicionó el Aprobado a fijar la atomicidad de la decisión y a aclarar qué guarda `lastRejection`; las dos entraron. Listo para su rama. |
| 2026-08-31 | review | Segunda pasada del `spec-reviewer`: los puntos 1 y 3 cerrados, pero `expectedStatus` había resuelto la lógica dejando abierta la **atomicidad**. El servicio lee el estado, consulta la tarifa y escribe un `UPDATE` que no condiciona por lo leído; en `READ COMMITTED` dos decisiones casi simultáneas pasan las dos la validación y la segunda pisa a la primera — el mismo "se resuelve solo" que el mecanismo existía para impedir. Se fija con `UPDATE ... WHERE status = $2` y cero filas como conflicto, que es el patrón que el agregado ya usa para la jornada abierta con `uq_time_entry_single_open`. Además: revertir usa el valor local y **no** un pull —el rechazo ocurre antes de escribir, así que `updated_at` no se mueve y la fila nunca vuelve a bajar—, y `lastRejection` guarda el código, no el texto. |
| 2026-08-31 | review | Hallazgos del `spec-reviewer` incorporados, los tres bloqueantes eran reales. (1) La razón del rechazo no bajaba por ningún camino: nace `time_entry.decision_reason`, que completa el trío quién/cuándo/por qué junto a `approved_by` y `approved_at` — y el spec deja de decir "ninguna columna nueva". (2) `approve()` tampoco validaba contra `REJECTED`, así que el fix que se pedía solo para `reject()` no producía el conflicto que la tabla describía; se resuelve con `expectedStatus` en la operación, que cubre las dos direcciones y además distingue la corrección deliberada del choque real. (3) La tabla de rechazos diferidos pedía descartes y reversiones que el `Synchronizer` no puede producir: entran al alcance, explícitos. Los códigos se renombraron a `DECISION_MATCHES` / `DECISION_CONFLICTS` porque los anteriores mentían cuando dos personas rechazaban lo mismo. |
| 2026-08-31 | borrador | Creado para llenar la primera de las dos tabs placeholder de la obra. Tres decisiones de producto al abrirlo: la vista es cronológica con total arriba y no agrupada por persona; la ventana es toda la obra y no los 7 días de las vistas de campo; y **aprobar entra**, lo que convierte un spec de lectura en el primero que escribe sin señal algo que un tercero pudo haber decidido antes. |
