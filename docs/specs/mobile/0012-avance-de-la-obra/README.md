---
id: SPEC-0012
title: "Avance de la obra"
aliases:
  - "SPEC-0012: Avance de la obra"
type: spec
platform: mobile
status: en-implementacion
goal: "La tab Avance responde de un vistazo cómo va la obra —en qué estado está y desde cuándo, la foto del antes contra la última, cuánto se trabajó y la última nota—, con el hilo completo de lo que pasó detrás de un toque, y William escribe ahí una nota con fotos eligiendo si queda interna o si el cliente la ve, también sin señal."
apps:
  - mobile
  - api
depends_on:
  - "0004-capa-local-y-sincronizacion"
  - "0009-la-obra-como-lugar"
  - "0010-fotos-de-la-obra"
  - "0011-horas-de-la-obra"
domain:
  - proyecto
  - contenido
  - acceso-del-cliente
  - registro-de-tiempo
frente: administrativo
created: 2026-09-01
updated: 2026-09-01
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0012: Avance de la obra

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0009-la-obra-como-lugar/README|SPEC-0009]], [[../0010-fotos-de-la-obra/README|SPEC-0010]], [[../0011-horas-de-la-obra/README|SPEC-0011]]
> - Frente: `administrativo`

---

## Problema

**Avance es el último `PlaceholderList` de la obra.** Está en
`project_screen.dart:143`, y el código que lo rodea ya prometía otra cosa:
`_tabInicial` abre en Avance cuando la obra está `IN_PROGRESS` *"porque es la
obra que se está trabajando hoy"*, y en Detalle cuando no, para no dejar a nadie
mirando *"un timeline que no se está moviendo"*. La pantalla que ese comentario
describe no existe: hoy quien entra a una obra en marcha cae en una lista
sintética de relleno.

Pero el hueco es más grande que una tab vacía: **la obra no tiene historia**.
Cada pedazo de lo que pasó vive en su propio silo —las fotos en Fotos, las
jornadas en Horas, el estado como un chip que solo dice el ahora— y la pregunta
que se hace un contratista todos los días no la contesta ninguno de los tres:
*¿qué pasó en esta obra, y en qué orden?* Con dos cuadrillas y varias obras a la
vez, eso hoy se reconstruye de memoria o rascando WhatsApp.

Los cambios de estado son el caso peor: **no se registran en ninguna parte**.
`project.status` guarda el ahora y pisa lo anterior. `audit_log` existe en la
base desde la migración `CommercialAndPublishing`, tiene su entity, y **no hay
una sola línea de código que escriba una fila**. Cuándo una obra arrancó, cuánto
estuvo en `ON_HOLD` y cuándo se dio por terminada es información que el sistema
tuvo delante y tiró.

Y falta el otro lado. **William no tiene dónde escribir.** `project_update`
existe —tabla, entity y su fila de assets— y el único camino que la escribe es
`POST /client-access/updates/:projectId`: no lo llama ninguna pantalla, fuerza
`visibility: 'CLIENT'`, se auto-aprueba y publica al portal en el mismo acto.
O sea, la bitácora de la obra ya está en la base y desde el producto no se puede
escribir una nota sin mandársela al cliente.

## Alcance

### Entra

**La tab Avance de `ProjectScreen`.** En la práctica la usan `OWNER` y `ADMIN`.
`ObraScreen` —la del `WORKER` y el `FOREMAN`, con sus tabs Registro, Cuadrilla y
Detalle— **no se toca**, igual que en SPEC-0011. Vale también la misma
advertencia de aquel spec: eso es una garantía de navegación, no de acceso; lo
que manda es el permiso de cada acción.

#### La vista de estado

**Lo primero que se ve es cómo va la obra**, no qué pasó. Cinco bloques, en este
orden, y ninguno pide desplazarse para existir:

| Bloque | Qué muestra | De dónde sale |
|---|---|---|
| **Estado y escalera** | El estado actual con desde cuándo, y dónde cae en el ciclo de vida | `project.status` y el hito más reciente de `project_status_change` |
| **El antes y lo último** | Dos fotos lado a lado, con su etiqueta y su fecha | `media_asset`: la más vieja etiquetada `BEFORE`, y la más reciente de la obra |
| **Las cifras** | Horas trabajadas, días en obra, fotos | `time_entry` y `media_asset`, agregados |
| **Última nota** | El texto, el autor y la fecha de la más reciente | `project_update` |
| **Ver todo lo que pasó** | Una línea con el conteo, que abre el hilo | Las cuatro fuentes, contadas |

**La escalera indica posición, no historia.** `LEAD → ESTIMATED → SCHEDULED →
IN_PROGRESS → COMPLETED` es el camino, y se marca hasta dónde llegó la obra: no
afirma que haya pasado por cada peldaño, porque de una obra anterior al historial
eso no se sabe. `ON_HOLD` se muestra en la posición de `IN_PROGRESS` con su tono
de advertencia —es una pausa dentro de la ejecución, no una etapa—, y `CANCELLED`
no tiene escalera: una obra cancelada no está en ningún punto del camino.

**Nada de porcentajes.** Nadie calcula «45% del techo». Un porcentaje derivado de
las etapas o de las horas es un número inventado que termina repitiéndose al
cliente como si estuviera respaldado.

**El par de fotos es la comparación que este producto existe para producir.** A la
izquierda la del antes; a la derecha la más reciente —no la etiquetada `AFTER`,
que recién existe cuando la obra termina, y la pantalla tiene que servir durante—.
Sin foto del antes, ese lado dice en una línea que hay que sacarla antes de que la
cuadrilla empiece, que es el único momento en que se puede.

**Las horas son una cifra, no una lista.** Cuánto se trabajó es parte de cómo va la
obra; el desglose por día es de la tab Horas y no se repite acá.

#### El hilo, detrás de un toque

**Una sola lista cronológica, lo más reciente arriba**, en su propia pantalla. Se
llega desde la línea «Ver todo lo que pasó» y responde la otra pregunta: qué pasó
y en qué orden. Tres clases de entrada:

| Entrada | De dónde sale | Cómo se agrupa |
|---|---|---|
| **Hito de estado** | `project_status_change`, tabla nueva | Una fila por transición. Nunca se agrupa: es el esqueleto del hilo |
| **Nota de avance** | `project_update` | Una fila por nota, con su texto, su autor y sus fotos |
| **Fotos** | `media_asset` de la obra, por `captured_at` y etiqueta | Una fila por día y etiqueta. Cuarenta fotos de un techo son un día de trabajo, no cuarenta eventos; pero un antes y un durante del mismo día son dos momentos distintos |

**Las jornadas no entran al hilo.** Una obra con cinco días trabajados y dos fotos
mostraba cinco filas de fichaje y dos de obra: el avance quedaba tapado por
asistencia, que ya tiene su tab. En la vista de estado viven como cifra.

**Las fotos del marcaje tampoco**, por la misma razón que las excluye
`PhotosTab`: son evidencia de que alguien estaba parado ahí, no material de la
obra. El repositorio ya las filtra.

**Tocar una fila de fotos abre la tab Fotos.** El hilo cuenta la historia; el
detalle ya tiene su pantalla y no se duplica.

**El hilo se pagina desde el primer día**, de a 50 entradas ya agrupadas, con
más al llegar al final. Una obra de seis meses son cientos de entradas
repartidas en tablas locales, y la consulta que las mezcla se hace lenta
mucho antes de que se note en la obra de prueba. Descubrirlo con los datos de
William adentro es tarde, y retrofitear paginación obliga a rehacer la consulta
y el scroll.

#### Escribir una nota

- **Texto libre y obligatorio**, con las fotos de la obra que se quieran
  adjuntar. Sin texto no hay nota: una nota vacía con fotos es lo que ya hace
  la tab Fotos.
- **La visibilidad se elige al escribir**, entre dos: **interna** o **el cliente
  la ve**. Interna es el default — es la bitácora de la obra, y que el cliente
  vea algo es una decisión, no un descuido.
- **`PUBLIC` no está en el selector.** Publicar al portafolio es un acto de otro
  frente (`publicidad`, SPEC-0005 de web), tiene su propia puerta y arrastra el
  invariante del EXIF. Una nota no se publica al mundo desde acá.
- **Solo se adjuntan fotos ya sincronizadas.** Una foto que todavía está en la
  bandeja aparece en el selector deshabilitada, con su razón visible. Si se
  adjuntara, el servidor recibiría un `project_update_asset` apuntando a un
  `media_asset` que para él no existe todavía, y la nota entera fallaría por una
  clave foránea.
- **Una nota para el cliente eleva sus fotos a `CLIENT`**, en la misma
  transacción, y solo las que estén en `INTERNAL`. Una foto que ya es `PUBLIC`
  no se toca: la escalera sube, nunca baja.

  Sin esto la nota se publica y **sus fotos desaparecen del portal sin error ni
  aviso**. `toClientView` arma el mapa de fotos visibles solo con las
  `visibility = 'CLIENT'` de la obra y después resuelve las de cada nota contra
  ese mapa, descartando en silencio las que no encuentra
  (`client-portal.service.ts`, `links.filter(...).map(byId.get).filter(Boolean)`).
  Una nota `CLIENT` con dos fotos `INTERNAL` adjuntas llega al cliente como un
  párrafo pelado.

  **La elevación pasa por `MediaService.setVisibility`, no escribe la columna.**
  La regla de subir de a un escalón ya vive ahí (`pedido > actual + 1` rechaza el
  salto) y es la única restricción de la escalera que no está en la base: el
  único gate de base es el del EXIF para `PUBLIC`. Dos caminos de código
  imponiendo la misma regla por separado es cómo se separan.

  **Elevar acá no saltea la escalera, la ejerce**: elegir esas fotos y marcar la
  nota como visible **es** el acto explícito, sobre fotos concretas y no sobre
  la galería entera. Y llega hasta `CLIENT`, no más — `PUBLIC` sigue exigiendo
  su propia puerta y el EXIF limpio (regla 17). Quien escribe notas es `OWNER` o
  `ADMIN`, que ya tienen `media.visibility`, así que no hay un permiso que
  esquivar. **La pantalla dice cuántas fotos van a cambiar de nivel antes de
  guardar**: que una foto pase a ser visible para el cliente nunca es un efecto
  invisible.
- **El aviso de `STAGES`, con su salida.** Si el proyecto tiene
  `client_visibility_mode` en `STAGES` —el default, y la mitigación declarada en
  la visión— marcar la nota como visible para el cliente **no la hace visible**:
  el portal devuelve `updates: []` y `photos: []` sin mirar nada más. La pantalla
  lo dice en el momento de elegir. Sin ese aviso William cree que mandó algo y
  del otro lado no hay nada.
- **Y cambiar el modo entra al alcance**, que es lo que hace que lo anterior no
  sea decorativo: hoy **ninguna pantalla puede cambiar `client_visibility_mode`**
  —`create` lo fuerza a etapas en `project_repository.dart` y ningún formulario
  lo ofrece—, así que sin esto la opción "el cliente la ve" es inerte para
  siempre y ninguna nota `CLIENT` sería visible jamás. Es un interruptor en la
  tab Detalle de la obra, con `projects.write`, que viaja por el
  `project.update` que ya existe: el campo está en `UpdateProjectDto`, en la
  tabla local y en el contrato. Falta el control, nada más.

#### El historial de estados, que hay que empezar a guardar

Es lo que hoy no existe y sin lo cual el hilo no tiene esqueleto. **Tabla nueva
`project_status_change`**, y el detalle está en *Modelo de dominio afectado*.

La escribe **el servidor**, en la misma transacción que aplica el cambio, y por
los dos caminos: la puerta REST y la bandeja de salida. Así el historial es
igual de completo venga del teléfono o del panel, y no depende de que un cliente
se acuerde de registrarlo.

**Y toda obra nace con su hito de origen**, escrito por `ProjectsService.create`.
Las que ya existían no reciben ninguno —ver el riesgo materializado abajo—: su
hilo se ancla en `created_at`, que es lo único que se sabe de ellas. Sin eso el
invariante vale solo para las obras anteriores al despliegue: una obra creada
después no tiene ninguna fila hasta su primera transición, y el hilo arrancaría
sin esqueleto justo en las obras nuevas, que son todas las que importan. Peor:
la lógica sin señal de más abajo se apoya en que **siempre** hay un hito
anterior del cual sacar el estado de partida, y para una obra nueva sin
sincronizar eso sería falso.

### No entra

- **Editar o borrar una nota.** Una nota es un asiento de bitácora con fecha y
  autor; corregirla es escritura sobre el rastro, y merece decidir antes si se
  edita en el lugar o se anula y se escribe otra —como una factura (regla 16)—.
  Se deja afuera a conciencia, con el mismo criterio que SPEC-0011 usó para
  editar horas.
- **Cambiar la visibilidad de una nota ya escrita.** Es la escalera del dominio
  aplicada al mismo objeto y el patrón ya existe para fotos
  (`media.visibility`), pero abre una operación de cola más y un camino de
  decisión más. **Queda un callejón conocido**: una nota escrita como interna no
  puede llegar al cliente después. Su trigger es la primera vez que a William le
  haga falta; ahí entra con su spec, o como deuda si se posterga otra vez.
- **Los cambios de estado retroactivos de las obras que ya existen.** El
  historial arranca el día que esto se despliega; ver *Modelo de dominio
  afectado*.
- **Comentarios, respuestas o cualquier cosa bidireccional.** El portal no es un
  chat y la ficha de [[../../../domain/acceso-del-cliente|Acceso del Cliente]] lo
  dice explícitamente.
- **La tab Avance en el panel web.** El panel todavía no tiene detalle de obra
  —SPEC-0009 de web está en Review—. Cuando lo tenga, hereda el mismo hilo, y
  los cambios de API de este spec ya lo dejan servido.
- **Escribir notas desde el campo.** El `FOREMAN` no gana pantalla nueva: se
  mantiene el precedente de SPEC-0009 y SPEC-0011 de no tocar `ObraScreen`.
- **`audit_log`.** Sigue sin usarse. Es una tabla de auditoría genérica —sin
  `updated_at` ni `deleted_at`, que es de lo que depende el pull— y convertirla
  en el feed de una pantalla la ata a un contrato de UI. El historial de estados
  es un hecho del dominio de [[../../../domain/proyecto|Proyecto]], no una traza
  técnica.

## Modelo de dominio afectado

- [[../../../domain/proyecto|Proyecto]] — el historial de estados
- [[../../../domain/acceso-del-cliente|Acceso del Cliente]] — `project_update`
- [[../../../domain/contenido|Contenido]] — las fotos que la nota adjunta, y la
  única escritura nueva sobre su escalera: adjuntar a una nota `CLIENT` eleva
  `INTERNAL → CLIENT`, nunca más arriba y nunca hacia abajo
- [[../../../domain/registro-de-tiempo|Registro de Tiempo]] — solo lectura, para
  la fila de jornadas del día

**Ningún agregado nuevo, una tabla nueva.** Revisado por `domain-guardian`
(regla 28). **Tres actualizaciones de ficha, en el mismo commit que la
migración** — no después, o el modelo escrito y el modelo real arrancan
divergiendo:

| Ficha | Qué se agrega |
|---|---|
| `proyecto.md` | La sub-tabla `project_status_change` con sus atributos, el invariante append-only, el de "la fila se escribe solo cuando `status` cambió respecto al valor actual", y qué garantiza y qué **no** garantiza el hito sembrado. Y `project_update`, que se muda acá |
| `acceso-del-cliente.md` | Pierde la tabla de `project_update` y queda con la referencia: qué llega al portal y bajo qué condición —`visibility = CLIENT`, `published_at` no nulo, `client_visibility_mode ≠ STAGES`—. Y que **la aprobación no es un paso separado**: es la misma acción de `OWNER`/`ADMIN` al escribir, sin segundo actor |
| `contenido.md` | La relación de escritura nueva: escribir una nota `CLIENT` puede elevar `media_asset.visibility` de `INTERNAL` a `CLIENT`. Hoy la ficha lista esa relación como de solo lectura |

### `project_status_change`

La ficha de Proyecto ya declara el evento `EstadoCambiado`; esto es la tabla que
lo persiste, colgada del mismo agregado que `project_assignment`.

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | uuid | sí | UUIDv7, regla 18 |
| `company_id` | uuid | sí | Regla 6 |
| `project_id` | uuid | sí | |
| `from_status` | enum | no | Nulo en el hito de origen |
| `to_status` | enum | sí | |
| `changed_by_membership_id` | uuid | no | Siempre presente: toda fila la escribe alguien |
| `device_recorded_at` | timestamptz | sí | El `occurredAt` de la operación; por REST, el mismo instante que el del servidor |
| `server_received_at` | timestamptz | sí | Regla 10: con la cola de por medio nunca son la misma |
| `updated_at` / `deleted_at` | | sí / no | Lo que el pull necesita (regla 20) |

**Append-only.** No se edita ni se borra: una transición que ocurrió, ocurrió.
`deleted_at` está para no romper la forma que el pull espera de toda colección,
no porque algo la vaya a usar.

**Nace con `ENABLE` + `FORCE ROW LEVEL SECURITY` y su policy en la misma
migración que la crea**, sin roll-out posterior — regla 2 de
`apps/api/CLAUDE.md`. Que la migración fundacional haya separado las policies en
`EnableRls` es anterior a esa regla y no es precedente para una tabla nueva.

**La fila se escribe solo cuando el `status` efectivamente cambió**, comparado
contra `actual.status` y no contra "vino `status` en el payload". Son dos casos
distintos y ninguno de los dos puede dejar hito:

- **La transición se descarta.** El estado que llega por la bandeja ya no es
  válido y `ProjectsService.update` lo ignora sin fallar —`fromOutbox` con
  `shouldDiscardStatus`, lo único de `project` que no es última escritura gana—.
  Un hito ahí afirmaría un cambio que el proyecto nunca hizo.
- **El estado que llega es el que ya tiene.** `canTransition` devuelve `true`
  cuando `from === to` a propósito (*"quedarse donde está no es una transición"*,
  `project-status.ts`), así que un `update` que manda el mismo estado junto con
  otros campos pasa el guard y no se descarta. Si el hito se escribiera por
  "vino `status`", editar el nombre de una obra desde un formulario que manda la
  ficha entera llenaría el historial de transiciones de `IN_PROGRESS` a
  `IN_PROGRESS`.

**El hito de origen.** Toda obra tiene uno, y hay dos maneras de llegar a él:

| Origen | `from_status` | `changed_by_membership_id` | Qué afirma |
|---|---|---|---|
| `create`, obra nueva | nulo | el creador | La obra nació en ese estado. Es un hecho |
| La migración, obra preexistente | nulo | **nulo** | Así estaba cuando empezó a registrarse. **No afirma** que haya nacido así |

**`from_status IS NULL AND changed_by_membership_id IS NULL` es la señal, y es un
invariante de la tabla, no una convención de esta pantalla.** Una obra que hoy
está en `COMPLETED` pero pasó por `SCHEDULED` e `IN_PROGRESS` recibe una fila que
dice "a `COMPLETED`, el día que se creó" — estructuralmente idéntica a una
transición real. Delegarle la honestidad de eso a que una pantalla la pinte bien
es exactamente lo que la regla 17 no acepta para el EXIF, y acá vale igual: el
panel web hereda este hilo, y cualquier reporte futuro lee la misma tabla. La
distinción tiene que poder hacerse desde la base, sin releer este spec.

No se inventan las transiciones intermedias que nadie registró.

### `project_update`

**Un solo cambio de esquema.** Ya extiende `SoftDeletableTenantEntity`, así que
tiene `updated_at` y `deleted_at` y baja por el pull tal como está. Lo que falta
es un **`CHECK (visibility IN ('INTERNAL','CLIENT'))`**: la columna reusa el enum
`media_visibility`, así que a nivel de base admite `PUBLIC` aunque ninguna
pantalla lo ofrezca. Que una nota no se publique al mundo no puede depender del
`@IsEnum` de un DTO — es el mismo principio por el que el gate del EXIF es un
trigger y no una validación de formulario (regla 17).

Lo que cambia es de quién es: **deja de ser una tabla del portal para ser la
bitácora de la obra**, con el portal como uno de sus destinos. Hoy su única
escritura vive en `client-portal.service.ts` y fuerza `CLIENT`.

**La ficha se muda a [[../../../domain/proyecto|Proyecto]]**, junto a
`project_assignment` y `project_status_change`: los tres son hechos historizados
que cuelgan de la obra, y de uno de ellos el portal es consumidor, no dueño. En
[[../../../domain/acceso-del-cliente|Acceso del Cliente]] queda la referencia y
no una copia de la tabla — dos fichas con la misma tabla es la definición de cuál
se va a desactualizar primero.

El invariante *"ningún `project_update` es visible sin `approved_by` y
`published_at`"* **se mantiene y no se relaja**: una nota interna nace con los
dos en nulo, y una marcada para el cliente los recibe en el acto de escribirla,
con el autor como aprobador. Quien puede escribirla es `OWNER` o `ADMIN`
(`projects.write`) — la misma gente que aprueba, así que no hay un paso de
aprobación que agregue nada.

**Y eso no es una licencia de este spec: es lo que el único camino de escritura
ya hacía.** `publishUpdate` escribe hoy `approvedBy` con el mismo
`tenant.membershipId` que pone en `author`. No se relaja el invariante, se
generaliza un patrón que existía sin estar dicho. Lo que hay que escribir en la
ficha es justamente eso: que **no existe un segundo actor que revise**, porque
"aprobación explícita" a secas se lee como si lo hubiera.

## Comportamiento sin señal

**Leer es local, entero.** Para `OWNER` y `ADMIN` el pull no está acotado, así
que las cuatro fuentes del hilo bajan completas y la pantalla no hace una sola
lectura de red. Consistente con toda la app: se lee Drift y no se pregunta si
hay señal.

Eso obliga a **dos colecciones nuevas en el pull**: `projectUpdates` y
`projectStatusChanges`, con sus bajas. Para `WORKER` y `FOREMAN` van acotadas
por `asignadoA(...)` como el resto —hoy ninguno de los dos llega a esta
pantalla, y el pull no se apoya en eso: lo que baja queda en disco y un teléfono
perdido ya tiene los datos—.

**Escribir una nota tampoco espera.** Nace local con su UUIDv7, queda `pending`
y se encola. Es el patrón de `media.register` y `customer.create`: el servidor
crea la fila **con el id del dispositivo**, así que un reintento responde
`duplicate` y no duplica (regla 19). No hace falta nada nuevo en el
sincronizador — a diferencia de SPEC-0011, acá no hay estado ajeno contra el
cual chocar.

**Los hitos de estado no se escriben en local, se leen de la bandeja.** Un
cambio de estado hecho sin señal ya viaja como `project.update` desde SPEC-0005;
mientras esa operación siga en la cola, el hilo **pinta el hito desde la propia
`OutboxOperations`** —tiene `type`, `targetId`, `payload` y `occurredAt`, que es
todo lo que hace falta— marcado como pendiente. Cuando sincroniza, la operación
sale de la cola y el pull trae la fila real.

**El estado de partida de un hito pendiente sale del hilo, no de la bandeja.**
`changeStatus` encola `{'status': nuevo}` —solo el estado nuevo— y ya sobreescribió
el `status` local, así que la operación por sí sola no puede decir de dónde venía.
No hace falta que lo diga: **el `from` de un hito pendiente es el `to_status` del
hito inmediatamente anterior del hilo**. En una obra nueva siempre hay uno,
porque `create` le escribe el suyo — por esto `create` está en el alcance y no es
simetría por gusto. En una obra anterior al historial puede no haberlo, y
entonces el pendiente se muestra sin origen: de dónde venía es justamente lo que
nadie registró. Con **dos o más transiciones encoladas**
se encadenan por `occurredAt` —el mismo orden con el que el servidor va a
aplicarlas— y cada una toma como `from` el `to` de la anterior: el hilo muestra
las dos, las dos pendientes. Nada de esto toca el payload de `project.update`.

La alternativa era escribir el hito local de forma optimista y que el servidor
lo creara con ese id. Se descarta: la transición se puede descartar del lado del
servidor sin fallar, y ahí el teléfono quedaría con un hito que no existe en
ningún lado, sin ningún camino de resultado que le avise. Leer la bandeja no
tiene ese agujero — **si la operación desapareció y el pull no trajo hito, es
que no hubo cambio**, que es exactamente la verdad.

| Situación | Qué se ve |
|---|---|
| Nota escrita sin señal | En el hilo al instante, marcada como pendiente de subir |
| Cambio de estado sin señal | Hito pendiente, leído de la bandeja, con el `from` del hito anterior del hilo |
| Dos cambios de estado encolados | Los dos hitos, encadenados por `occurredAt`, los dos pendientes |
| El servidor descarta la transición | El hito pendiente desaparece cuando la operación sale de la cola, y el estado del proyecto vuelve al del servidor en el siguiente pull |
| Foto todavía en la bandeja | No se puede adjuntar a una nota; el selector la muestra deshabilitada con su razón |

## Flujo de usuario

1. William abre una obra en marcha. Cae en **Avance**, que es la primera tab.
2. Lee de arriba hacia abajo: *hoy, 3 personas · 22 h · 8 fotos*; ayer, la nota
   que escribió; el martes, **En proceso** desde Agendada.
3. Toca la fila de fotos del martes y aterriza en la tab Fotos.
4. Vuelve, toca **Escribir nota**, describe que faltan las tejas del lado norte,
   adjunta dos fotos y la deja **interna**. La nota aparece arriba del hilo.
5. Al día siguiente escribe otra, esta vez marcada para el cliente. La pantalla
   le avisa que esta obra está en modo Etapas y que el cliente no la va a ver, y
   le ofrece cambiar el modo.

## Contrato de API

Toda la sección cierra con `pnpm contracts:generate` (regla 8). Antes del PR,
`contract-watcher`.

### `POST /projects/:projectId/updates` — nuevo

Permiso: `projects.write`.

```http
POST /projects/019... /updates
{
  "id": "019...",              // UUIDv7 del dispositivo; opcional por REST
  "body": "Faltan las tejas del lado norte",
  "visibility": "INTERNAL",    // INTERNAL | CLIENT
  "assetIds": ["019...", "019..."]
}
```

Con `visibility: "CLIENT"` el servidor escribe `approved_by` con el autor y
`published_at` con el instante, **y sube a `CLIENT` los `assetIds` que estén en
`INTERNAL`, en la misma transacción**. Los que ya sean `PUBLIC` no se tocan. Con
`INTERNAL`, los dos campos quedan en nulo y ninguna foto cambia de nivel.

Un `assetId` que no pertenece a esa obra se rechaza: adjuntar es elegir entre
las fotos de la obra, no entre todas las de la empresa.

### `POST /client-access/updates/:projectId` — se retira

Lo reemplaza el de arriba. Escribe la misma tabla con reglas distintas —fuerza
`CLIENT`, no acepta el id del cliente y no valida la escalera—, no lo llama
ninguna pantalla y dejar los dos caminos vivos garantiza que se separen. Sale
del contrato en el mismo commit.

### `GET /sync` — dos colecciones nuevas

`projectUpdates` y `projectStatusChanges`, cada una con su lista en `deleted`.
Las fotos de una nota **viajan adentro de la nota**, no como colección propia:
`project_update_asset` no tiene `updated_at` ni `deleted_at`, exactamente el
mismo caso que `media_tag`, que ya viaja dentro del asset.

### `SYNC_OPERATIONS` — una operación nueva

| Operación | Permiso | `targetId` |
|---|---|---|
| `projectUpdate.create` | `projects.write` | El id de la nota |

`OPERATION_PERMISSION` la declara o no compila, que es lo que ese `satisfies`
existe para garantizar (regla 7).

### `ProjectsService.update` — escribe el hito

Cuando `status` cambia de verdad, escribe la fila de `project_status_change` en
la misma transacción. El autor sale de `currentTenant()`.

**`occurredAt` sí obliga a cambiar la firma.** Hoy `sync.service.ts` llama
`this.projects.update(op.targetId, dto, { fromOutbox: true })` y **descarta el
`occurredAt` de la operación**, que es justo el `device_recorded_at` del hito.
Sin pasarlo, la marca del dispositivo sería la del servidor y la regla 10 quedaría
en dos columnas con el mismo valor siempre. Por REST sí coinciden, y ahí no es
una pérdida: no hubo cola, así que no hay otra marca que capturar.

`ProjectsService.create` escribe su hito de origen con el mismo mecanismo.

## UI

Cero cadenas quemadas, todo por `l10n` en los dos idiomas, tokens del tema y los
dos modos (reglas 21 a 24). Se reusan `SectionCard`, `StatusLine`, `StatusChip`,
`EmptyState`, `FieldActionButton` y `ConfirmSheet`, que ya existen.

```
┌─────────────────────────────────────┐
│  [Escribir nota]                    │
├─────────────────────────────────────┤
│  HOY                                │
│   ▸ 3 personas · 22 h        →      │
│   ▸ 8 fotos  [▪][▪][▪][▪]+4  →      │
├─────────────────────────────────────┤
│  AYER                               │
│   ✎ "Faltan las tejas del norte"    │
│     William · Interna  [▪][▪]       │
├─────────────────────────────────────┤
│  MARTES 26                          │
│   ● Agendada → En proceso           │
│     William                         │
└─────────────────────────────────────┘
```

- **El hito de estado es la fila con más peso visual.** Es el esqueleto: lo que
  se busca al recorrer el hilo hacia atrás es dónde cambió algo.
- **La nota lleva su nivel a la vista**, como las fotos llevan el suyo desde
  SPEC-0010. Que algo sea visible para el cliente nunca se deduce.
- **Antes de guardar una nota para el cliente, la pantalla dice cuántas fotos
  cambian de nivel.** Es la única parte del flujo que modifica algo fuera de la
  nota que se está escribiendo, y no puede ser un efecto silencioso.
- **El interruptor del modo vive en la tab Detalle**, no dentro del formulario de
  la nota: es una propiedad de la obra y no de lo que se está escribiendo. Desde
  el aviso se llega ahí.
- **Vacío que no fiscaliza** (regla de copy de SPEC-0009): una obra sin nada
  todavía dice que acá va a aparecer lo que pase, no que falta hacer algo.
- **Lo pendiente de subir se distingue de lo confirmado**, con el mismo lenguaje
  visual que ya usan las fotos y las jornadas.

## Criterios de aceptación

- [ ] La tab Avance de `ProjectScreen` ya no renderiza `PlaceholderList`, y
      `PlaceholderList` deja de importarse en `project_screen.dart`
- [ ] La tab abre mostrando el estado con su fecha, la escalera del ciclo, el par
      de fotos, las cifras y la última nota **sin desplazarse**
- [ ] La escalera marca hasta el estado actual; `ON_HOLD` cae en la posición de
      `IN_PROGRESS` y `CANCELLED` no muestra escalera
- [ ] La pantalla no muestra ningún porcentaje de avance
- [ ] El par de fotos es la más vieja etiquetada `BEFORE` y la más reciente de la
      obra; sin la del antes, ese lado explica cuándo hay que sacarla
- [ ] Las horas aparecen como cifra agregada, nunca como filas por día
- [ ] «Ver todo lo que pasó» abre el hilo con su conteo, y el hilo mezcla las tres
      clases de entrada en un solo orden descendente por fecha
- [ ] Las jornadas **no** aparecen como entradas del hilo
- [ ] Cambiar el estado de una obra escribe una fila en `project_status_change`
      con `from_status`, `to_status`, autor y las dos marcas de tiempo
- [ ] Una transición que la bandeja manda y el servidor descarta **no** escribe
      fila de historial
- [ ] Una obra anterior al historial ancla su hilo en `created_at` y **no afirma
      ningún estado** en esa fecha
- [ ] Las fotos de un mismo día se parten por etiqueta, y una foto con varias
      cuenta una sola vez
- [ ] Crear una obra escribe su hito de origen con `from_status` nulo y el
      creador como autor, y **ninguna obra queda sin hito**
- [ ] Un `update` que manda el estado que la obra ya tiene no escribe hito
- [ ] `project_status_change` nace con RLS forzado y su policy en la misma
      migración que la crea
- [ ] `project_update.visibility` rechaza `PUBLIC` **en la base**, no solo en el DTO
- [ ] `device_recorded_at` de un hito que llegó por la bandeja es el `occurredAt`
      de la operación, distinto de `server_received_at`
- [ ] Las tres fichas de dominio quedan actualizadas en el mismo commit que la
      migración, con `project_update` mudada a `proyecto.md`. **El mapa no se
      toca**: solo lleva agregados, y `project_status_change` cuelga de Proyecto
      igual que `project_assignment`, que tampoco tiene caja
- [ ] `GET /sync` devuelve `projectUpdates` y `projectStatusChanges` con
      sus bajas, acotadas por asignación para `WORKER` y `FOREMAN`
- [ ] Una nota escrita en modo avión aparece en el hilo al instante, marcada como
      pendiente, y llega al servidor con su id de dispositivo al volver la red
- [ ] Reintentar la misma nota responde `duplicate` y no crea una segunda fila
- [ ] Una nota `INTERNAL` queda con `approved_by` y `published_at` en nulo; una
      `CLIENT`, con los dos escritos
- [ ] El portal del cliente sigue sin ver las notas `INTERNAL`, y tampoco ve las
      `CLIENT` de una obra en modo `STAGES`
- [ ] Elegir "el cliente la ve" en una obra en modo `STAGES` muestra el aviso
- [ ] Una foto que no terminó de sincronizar no se puede adjuntar
- [ ] Guardar una nota `CLIENT` deja en `CLIENT` sus fotos adjuntas que estaban
      en `INTERNAL`, no toca las que ya eran `PUBLIC`, y el portal devuelve esa
      nota **con sus fotos** y no con la lista vacía
- [ ] La tab Detalle permite cambiar `client_visibility_mode` con
      `projects.write`, y el cambio viaja por `project.update`
- [ ] El hilo carga de a 50 entradas y trae más al llegar al final, sin leer las
      cuatro tablas enteras en cada carga
- [ ] Dos cambios de estado encolados sin señal se ven como dos hitos
      encadenados, cada uno con el estado de partida correcto
- [ ] `/client-access/updates/{projectId}` ya no está entre las rutas de
      `openapi.json` —hoy sí está— y `/projects/{projectId}/updates` sí
- [ ] `openapi.json` regenerado y los clientes de TS y Dart al día
- [ ] Ni una cadena visible fuera de `l10n`, ni un valor de estilo literal, en
      los dos temas y los dos idiomas
- [ ] `domain-guardian` antes de la migración; `contract-watcher` al cerrar el
      API; `code-reviewer` antes del PR

## Riesgos / consideraciones

- **`projectUpdate.create` al lado de `project.update`.** Dos operaciones de la
  cola que se leen casi igual y hacen cosas distintas: una escribe una nota, la
  otra edita la obra. Se conserva el nombre del dominio en vez de inventar uno
  más claro, porque un contrato que no se llama como la tabla envejece peor. El
  riesgo es de lectura y se mitiga con el sufijo, pero conviene tenerlo a la
  vista al revisar el `switch` del servicio.
- **El hilo cruza cuatro tablas locales.** ~~Si se resuelve trayendo todo y
  cortando en Dart, la paginación es decorativa.~~ **Resuelto al implementar**:
  un `UNION ALL` de las cinco fuentes —las cuatro tablas más la bandeja— con su
  `ORDER BY` y su `LIMIT` en la base. Drift observa las cinco y vuelve a emitir
  cuando cualquiera cambia, así que una nota escrita sin señal aparece igual de
  rápido. La alternativa —combinar cinco streams en Dart— pedía una dependencia
  nueva (`rxdart`) y traía las tablas enteras en cada emisión.
- **Retirar un endpoint es romper contrato**, aunque hoy no lo llame nadie. Se
  hace ahora justamente porque nadie lo llama: con el panel web construido
  encima el costo se multiplica.
- **`client_visibility_mode` es el default que apaga esta feature.** La visión
  registra el frente del cliente como *construido contra la evidencia
  disponible* —William dijo "no mandamos fotos"— y `STAGES` es la mitigación
  declarada. Este spec no la toca: agrega el aviso para que la contradicción sea
  visible en la pantalla en vez de silenciosa.
- **~~El hito de origen sembrado se puede leer como un dato real.~~ Pasó.** La
  migración sembraba `to_status = status` con `device_recorded_at = created_at`:
  el hilo afirmaba que una obra estaba «En proceso» el día que se creó, cuando
  ese es el estado que tiene hoy. Ninguna aclaración de UI arregla un dato falso.
  **Resuelto el 2026-09-02**: el seed se retiró y el ancla pasó a salir de
  `project.created_at`, sin estado. Lo encontró William probando, no los tests —
  los tests verificaban que la fila sembrada se distinguiera de una atestiguada,
  que era la pregunta equivocada.

## ADRs relacionados

- [[../../../adr/0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]] — el
  portal y qué llega al cliente
- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — el contrato como fuente
- [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] — la forma de los errores

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-09-01 | borrador | Creado |
| 2026-09-01 | en-implementacion | API completo: migración con RLS y seed, el hito en `create` y `update`, `POST /projects/:id/updates`, `/client-access/updates` retirado, dos colecciones en el pull y `projectUpdate.create` en el lote. 92 unitarios y 68 e2e. Móvil: dos tablas locales, el hilo en una sola consulta, la tab, la hoja de nota y el interruptor del modo. 374 tests |
| 2026-09-01 | en-implementacion | Rama `feature/SPEC-0012-avance-de-la-obra`. Arranca por el dominio y el API |
| 2026-09-02 | en-implementacion | Corregido probando en el simulador: el hito que sembraba la migración **afirmaba el estado de hoy en la fecha de creación** — el riesgo que el propio spec declaraba. El seed se retira, el ancla sale de `project.created_at` sin estado, y `createdAt` baja al teléfono (esquema local v9). Las fotos de un día se parten por etiqueta, y cada tipo de entrada lleva su icono en el riel: sin eso una jornada y un grupo de fotos son el mismo renglón. 380 tests del móvil, 160 del API |
| 2026-09-02 | en-implementacion | Rediseño a partir de la prueba: la tab pasa de **hilo cronológico a vista de estado** —estado con su escalera, el antes contra lo último, cifras y última nota— y el hilo se muda a `ProgressHistoryScreen`, detrás de una línea. El `goal` cambia con la pantalla. En el hilo, la fecha deja de ser encabezado por fila y pasa a **columna fija**, con «hoy» y «ayer» en palabras. Y un hallazgo suyo de fuera del alcance: **la URL firmada se pedía en cada montaje** —cambiar de tab bastaba—, y como cada firma es otra URL, Flutter no podía cachear y el binario se rebajaba de Backblaze; ahora se cachea hasta un minuto antes de vencer y se olvida al cerrar sesión. 400 tests |
| 2026-09-02 | en-implementacion | Segunda vuelta de la prueba. En el hilo, línea entre días y fecha en negrita. Y un hallazgo suyo que era un bug mío silencioso: **`projectVisibilityStages` quedó definida dos veces en los dos `.arb`** —la mía pisó la del formulario de obra, que pasó a mostrar «Solo las etapas» donde decía «El cliente verá esta obra por etapas»—. Renombradas a `projectVisibilityMode*`, y `l10n_arb_test.dart` nuevo para que una clave duplicada o sin par en el otro idioma falle en vez de pasar en silencio; de paso cazó `placeholderProject`, viva en español y muerta en inglés. 403 tests |
| 2026-09-03 | en-implementacion | **El pull se caía en el teléfono con 200 del servidor.** `ProjectUpdate` tenía sus tres relaciones sin decorar, así que salían a `openapi.json` como requeridas y no nullables; el servidor manda solo los `*Id` y el cast del cliente generado tiraba `type 'Null' is not a subtype of Map<String, dynamic>` — con el parseo de la **respuesta entera** caído, no solo el de las notas. La entity venía del portal, donde su respuesta se armaba a mano y nunca pasaba por el cliente generado; sumarla al pull activó el defecto. Marcadas con `@ApiPropertyOptional()`, como ya estaban `Project.customer` y `ProjectStatusChange.changedBy`. `sync_contract_test.dart` nuevo parsea la respuesta real del servidor —ningún test lo hacía, y por eso 408 tests en verde convivían con el pull roto—. Las otras veinte relaciones con el mismo defecto van a DEBT-0012. 408 tests |
| 2026-09-03 | en-implementacion | Copy y remate visual. El aviso de visibilidad del alta pasa a `StatusChip` —el widget ya estaba escrito para ese caso y el formulario no lo usaba—, y la hoja de ayuda gana su botón tonal: en texto plano no se leía como salida. **El copy de esa ayuda le explicaba a William cómo ocultarle algo a su cliente** —«sin enterarse de que la obra estuvo pausada tres días»—: reescrito en positivo, sobre lo que el portal informa, y con la línea que faltaba sobre dónde se cambia el modo. `help_sheet_test.dart` nuevo, que no existía. 414 tests |
| 2026-09-03 | en-implementacion | Revisores. `contract-watcher`: contrato sincronizado, sin bloqueantes; su hallazgo —`crews.service.ts` carga `foreman` sin `foreman.user`, o sea que `Membership.user` ya tiene quien lo dispare— se sumó a DEBT-0012. `code-reviewer`: 33 criterios en `[x]` y **dos desvíos corregidos**. El conteo de «Ver todo lo que pasó» no miraba la bandeja, así que la tab prometía menos filas de las que el hilo abría con un cambio de estado sin señal; ahora lo cuenta y hay tres tests que atan conteo y largo del hilo. Y el aviso de Etapas **cambiaba el modo desde la hoja de nota**, donde el spec dice que no vaya: ahora lleva a Detalle, y el copy dice lo que hace. Dos menores: el `@Transactional()` de `view()` había quedado bajo un comentario huérfano, y los índices del esquema local van a DEBT-0013. 417 tests |
| 2026-09-03 | en-implementacion | Tres hallazgos de la prueba que entran acá por decisión suya, fuera del alcance del spec. **El estado de una dirección exigía dos letras y la app ofrece dieciséis países**: `@Length(2, 2)` fuera, texto libre hasta 100, label «Estado o provincia» y cinco tests de validación —«Alajuela» y «Sacatepéquez» entran, «MD» sigue entrando—. «Tomar foto» pasa a botón flotante, extendido y de 64dp: el FAB de Material mide 56 y esto se pulsa con guantes. Y la ficha del cliente ofrece crear una obra con él ya puesto, en el `action` del `SectionHeader` —otro widget que existía para esto—. La nota forzada queda fuera: es feature y va a spec propio. 418 tests del móvil, 97 unitarios |
| 2026-09-03 | en-implementacion | Segunda pasada de los revisores. `contract-watcher` volvió a dar sincronizado y cazó que el cambio del estado había quedado a medias: `toDto()` seguía con `.toUpperCase()`, así que «Alajuela» viajaba como «ALAJUELA». `code-reviewer` verificó los cuatro fixes sin regresiones y encontró dos más: el `SafeArea()` del botón flotante sumaba el inset del teléfono **por fuera** del margen, y la grilla reservaba un número fijo — en cualquier teléfono con barra gestual el botón tapaba la última fila; ahora la reserva incluye `MediaQuery.paddingOf(context).bottom` y hay un test que simula los 34 de un iPhone con Face ID, algo que la suite nunca hacía. Y las tres entradas de `PENDIENTES.md` que este mismo diff resolvía quedaron marcadas. 419 tests del móvil, 97 unitarios, 68 e2e |
| 2026-09-01 | aprobado | Aprobado. Queda una decisión abierta a propósito: adjuntar una foto interna a una nota `CLIENT` la eleva, en vez de que el selector ofrezca solo las que ya son visibles |
| 2026-09-01 | review | Corregido con `domain-guardian`: **una obra creada después del despliegue no tenía hito de origen**, y la lógica sin señal se apoyaba en que siempre hubiera uno — `create` lo escribe ahora. La señal que distingue un hito sembrado de uno real pasó de advertencia de UI a invariante de la tabla. El guard compara contra `actual.status`, porque `canTransition` acepta `from === to`. `occurredAt` no llegaba a `update()`. RLS en la migración que crea la tabla, `CHECK` para que `project_update` no admita `PUBLIC`, la elevación reusa `setVisibility`, y `project_update` se muda a `proyecto.md` |
| 2026-09-01 | review | Corregido con `spec-reviewer`: la ruta real del endpoint que se retira (`/client-access`, no `/client-portal`) y `GET /sync`; qué pasa con la visibilidad de las fotos adjuntas a una nota `CLIENT`, que el portal escondía en silencio; cambiar `client_visibility_mode`, sin lo cual la mitad de la feature era inerte; la paginación pasó de riesgo a alcance; y de dónde sale el estado de partida de un hito todavía pendiente |
