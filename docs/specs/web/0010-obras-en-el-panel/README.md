---
id: SPEC-0010
title: "Obras en el panel"
aliases:
  - "SPEC-0010: Obras en el panel"
type: spec
platform: web
status: en-implementacion
goal: "Desde el panel se listan las obras y se filtran por estado y por texto, se crea una eligiendo cliente y propiedad —y creando cualquiera de los dos sin salir del formulario—, se corrigen sus campos editables, su estado solo avanza por las transiciones que el dominio permite, y cerrarla pide la fecha real de fin contra un resumen de las horas que llevó y del desvío contra lo previsto; el cliente y la propiedad no se pueden cambiar después de crearla, y quien solo tiene `projects.read` no encuentra ningún control que escriba."
apps:
  - web
depends_on:
  - "0008-sesion-y-shell"
  - "0009-clientes-y-propiedades"
domain:
  - proyecto
  - cliente
frente: administrativo
created: 2026-09-02
updated: 2026-09-02
tags:
  - spec
  - spec/en-implementacion
  - web
---

# SPEC-0010: Obras en el panel

> **Meta**
> - Apps afectadas: `web`
> - Depende de: [[../0008-sesion-y-shell/README|SPEC-0008]], [[../0009-clientes-y-propiedades/README|SPEC-0009]]
> - Frente: `administrativo`

---

## Problema

El panel lista obras y no deja crear ninguna. Hoy la única forma de dar de alta una
obra es el teléfono ([[../../mobile/0005-proyectos-en-el-movil/README|SPEC-0005
móvil]]), y **William administra desde la oficina**: cargar nombre, tipo de trabajo,
descripción y dos fechas con el pulgar es la fricción que el panel viene a sacar.

Es el eslabón que sigue a [[../0009-clientes-y-propiedades/README|SPEC-0009]]. Con
cliente y propiedad cargables, la obra es lo único que separa al panel de poder
contar el ciclo entero: sin obra no hay foto que colgar, y sin foto no hay nada que
publicar. La cadena del panel es clientes → **obras** → fotos → publicar, y este es
el segundo tramo.

**El API está entero y no abre trabajo.** `POST`, `PATCH` y `DELETE` de proyecto
existen, `PATCH` ya valida la escalera de estados con `canTransition` y devuelve
`PROJECT_INVALID_TRANSITION`, y `POST` ya rechaza una propiedad que no sea del
cliente elegido. `PROJECT_INVALID_TRANSITION` ya está en `ERROR_CODES`, en
`openapi.json` y en los tipos generados. Este spec es pantalla contra endpoints
probados, y por eso `apps` es solo `web`.

## Alcance

### Entra

- **Lista de obras** con búsqueda por nombre de obra o de cliente, y filtro por los
  siete estados del dominio. La vista de tarjetas que dejó SPEC-0008 se conserva;
  se le suman los controles del encabezado y los dos estados vacíos.
- **Alta de obra completa**: cliente, propiedad, nombre, tipo de trabajo,
  descripción, fecha de inicio, fecha estimada de fin y estado inicial.
- **Crear cliente y propiedad sin salir del alta.** Detallado abajo — es la decisión
  que da forma a esta pantalla.
- **Ficha de la obra**: sus datos, con el cliente y la propiedad enlazados a donde
  viven.
- **Corregir** los campos editables. El cliente y la propiedad no lo son, y la ficha
  lo dice en vez de ofrecerlos y descartarlos.
- **Cerrar la obra con su resumen**: al pasar a `COMPLETED` se pide la fecha real de
  fin, contra las horas que llevó y qué tan cerca quedó de la fecha prevista.
- **Cambio de estado**, ofreciendo **solo las transiciones válidas** desde el estado
  actual, con confirmación al entrar en un estado terminal. **Cancelar es una de
  esas transiciones, no un segundo control**: es la salida del dominio cuando se
  eligió mal el cliente o la propiedad, y sale del mismo selector que las demás.
- **La escritura cuelga de `projects.write`**, que es OWNER y ADMIN. `FOREMAN`,
  `WORKER` y `ACCOUNTANT` tienen `projects.read` y ven la lista y la ficha: no
  pueden encontrar un botón que los lleve a un 403.

### No entra

- **Fotos, horas y avance de la obra.** Cada uno con su spec, y cada uno es una
  superficie de escritura propia. La ficha de esta entrega no lleva pestañas: una
  pestaña sola es ruido, y las pestañas llegan cuando llegue la segunda. El resumen
  de cierre **lee** las horas de la obra, pero no las lista, no las abre y no las
  aprueba: eso es la pantalla de Horas.
- **Asignar cuadrilla.** `POST /projects/{id}/assignments` existe, pero cuelga de
  `crews.write` y el roadmap lo pone en el frente `campo`. Este sería el primer spec
  del panel en cruzar de frente, y no hay razón para que sea este.
- **Publicar la obra al portafolio.** Es el frente `publicidad`.
- **Cambiar `client_visibility_mode`.** La obra se crea en `STAGES`, que es el
  default del dominio y del API. Pasar a `PROGRESS` es acción explícita y su lugar
  es el spec que sea dueño del portal —
  [[../0006-portal-del-cliente/README|SPEC-0006 web]]—, no un toggle suelto en un
  formulario de alta. El móvil hoy tampoco lo cambia: lo muestra y explica.
- **Borrar una obra.** Decidido abajo.
- **La ficha completa del cliente dentro del alta.** El diálogo pide lo mínimo; el
  resto se llena desde SPEC-0009, que es dueño de esa pantalla. Mismo criterio que
  tomó SPEC-0005 en el móvil.

## Modelo de dominio afectado

- [[../../../domain/proyecto|proyecto]]
- [[../../../domain/cliente|cliente]] — se lee, y se crea desde el alta

**No introduce agregados, campos ni invariantes.** Lo que hace es poner en el panel
tres reglas que hasta hoy solo respetaba el móvil.

### El cliente y la propiedad se fijan al crear

La ficha del dominio ya lo dice, y ya dice por qué: una obra tiene horas, fotos,
estimados y facturas colgando, así que cambiarle el cliente reasigna todo eso a otra
persona. `UpdateProjectDto` no acepta `customerId` ni `siteId`, y eso no es un
descuido — se decidió el 2026-08-10 justamente al encontrar que el formulario de
edición los ofrecía y el servidor los descartaba **en silencio**.

El panel no puede repetir ese error. En la corrección los dos campos se muestran
como dato, no como control, con la frase que el móvil ya escribió:

> El cliente y la propiedad se fijan al crear la obra. Para cambiarlos, cancele
> esta obra y cree una nueva.

### La propiedad tiene que ser del cliente

`ProjectsService.create` lo comprueba y rechaza con 400 si no coinciden. El panel no
debería llegar a verlo nunca: el selector de propiedad se llena desde
`GET /customers/{id}/sites` del cliente ya elegido, así que no hay forma de armar el
par inválido desde la pantalla.

**El caso que sí puede pasar llega con otro status.** Si la propiedad se borra entre
que se cargó el selector y se envió el formulario, el servicio corta un renglón antes
—`site` ya es `null`— y responde **404, no 400**: la comparación `customerId` nunca
se evalúa. Los dos se muestran con el mensaje del servidor y ninguno lleva código
propio, alcanza con el genérico (regla 8); pero el manejo de error tiene que cubrir
**los dos status**, porque el 404 es el único de los dos que ocurre de verdad.

**Elegir otro cliente vacía la propiedad elegida.** Es la única forma de que el par
no quede cruzado si alguien vuelve atrás en el formulario.

### No se borra una obra: se cancela

`ProjectsService.remove` marca `deleted_at` y no comprueba nada, igual que hacía
`customers.remove` antes de SPEC-0009. Pero acá la salida no es agregarle un trigger
—es **no exponerlo**.

El dominio ya tiene el camino, y es `CANCELLED`: *"si se eligió mal, se cancela la
obra y se crea de nuevo — que además deja rastro"*, y *"`CANCELLED` no borra nada:
las horas trabajadas siguen siendo horas pagables"*. Un botón de borrar al lado de
uno de cancelar son dos caminos para lo mismo, y el que borra es el que no deja
rastro. El invariante propio de la ficha alcanza para sostenerlo: no hace falta
apoyarse en la regla 12, que habla de `time_entry` y no de la obra.

`DELETE /projects/{id}` queda como está y sin consumidor en el panel. **Que siga
abierto y sin comprobar es deuda**, y es más grave de lo que parece: no es la misma
que SPEC-0009 cerró, es **una puerta trasera contra ella**.

El trigger `enforce_customer_no_history` que trajo SPEC-0009 retiene al cliente
mirando `project.deleted_at IS NULL`, sin importar el estado de la obra. Si alguien
llama `DELETE /projects/{id}` sobre una obra viva —con horas cargadas y fotos
publicadas— en vez de cancelarla, el trigger deja de verla, y el cliente pasa a ser
borrable, cascadeando el borrado suave de sus propiedades. El invariante que la ficha
de cliente declara queda roto por un camino que ninguna de las dos fichas nombra.

Y el borrado no cascadea nada de la obra: quedan colgando `time_entry`,
`media_asset`, `project_assignment`, `before_after_pair`, `project_update`,
`estimate` e `invoice` —facturas enviadas, numeradas, que la regla 16 protege— más
`published_project.source_project_id`, que puede dejar una obra borrada en el panel y
todavía visible en el portafolio público.

**Quedó registrada como
[[../../../tech-debt/0014-borrar-obra-sin-comprobacion|DEBT-0014]]**, severidad
alta, el 2026-09-05 al implementar la tanda 1 — en esos términos y no como
"cualquiera puede borrar una obra con cosas colgando": lo que la despierta es que
es un bypass de un invariante que ya vive en la base. Su trigger es el primero de
dos: que alguna pantalla vaya a exponer borrar obra, o la primera empresa real con
obras facturadas.

## Flujo de usuario

```
Obras → [+ Nueva obra]
   │
   ├─ Cliente        ── no está ─→ [+ Nuevo] ─→ diálogo (nombre + propiedad)
   │                                              └─→ vuelve elegido
   ├─ Propiedad      ── no tiene ─→ [+ Nueva] ─→ diálogo (dirección)
   │                                              └─→ vuelve elegida
   ├─ Nombre de la obra          (obligatorio)
   ├─ Tipo de trabajo · Descripción
   ├─ Inicio · Fin estimado
   └─ Estado inicial             (default: Prospecto)
        │
        └─ Guardar ─→ ficha de la obra
```

### Crear cliente y propiedad sin salir del alta

Es la decisión que da forma a la pantalla. Quien está creando una obra y descubre
que el cliente no tiene ninguna propiedad cargada tiene dos salidas: irse a
Clientes y volver, perdiendo lo escrito, o cargarla ahí mismo. La primera es
exactamente lo que SPEC-0009 declaró que hace que alguien deje de usar el panel.

- **La propiedad reusa `site-dialog` tal cual.** Ya existe desde SPEC-0009, ya
  escribe contra `POST /customers/{id}/sites`, y ya resuelve el caso.
- **El cliente necesita una versión en diálogo.** `customer-form` es pantalla
  completa con stepper y no entra en un `mat-dialog`. El diálogo pide **el nombre
  para mostrar y la dirección de la primera propiedad**, que es lo mínimo para que
  la obra se pueda crear, y usa el mismo `CreateCustomerDto` con `site` embebido
  que SPEC-0009 ya ejercita. Correo, teléfono, origen y facturación se completan
  después desde la ficha del cliente, y el diálogo lo dice al cerrar.

**Lo creado en el diálogo ya existe cuando el diálogo cierra.** No es un borrador
que se guarda junto con la obra: son dos escrituras separadas contra dos endpoints.
Eso tiene una consecuencia que la pantalla tiene que manejar y está abajo, en el
comportamiento sin señal.

### El estado se cambia con su propia acción, no desde el formulario

Diferencia consciente con el móvil, que ofrece el selector de estado dentro del
formulario de edición. En el panel el estado vive en la ficha, con su propio botón:

- El selector ofrece **solo las transiciones válidas** desde el estado actual, según
  la tabla del dominio. La escalera se respeta en el selector, no como advertencia
  después de fallar.
- Entrar en `COMPLETED` o `CANCELLED` **pide confirmación**, porque no se vuelve.
- En un estado terminal el control se muestra deshabilitado con su razón, no se
  esconde: que no se pueda cambiar es información.

La razón de separarlo: guardar la ficha entera desde un formulario que incluye el
estado dispara una transición como efecto secundario de corregir una fecha.
`canTransition` acepta a propósito quedarse en el mismo estado, así que el servidor
no lo atrapa. Y cuando llegue el historial de estados —SPEC-0012 móvil, en curso—
la diferencia entre "cambié el estado" y "guardé la ficha" deja de ser cosmética.

### El estado inicial

El alta ofrece seis de los siete estados —**`CANCELLED` queda fuera**, como en el
móvil— y **arranca en `LEAD`**, no en `IN_PROGRESS` como el móvil.

No es inconsistencia: el teléfono está parado en la obra y lo normal ahí es que el
trabajo ya empezó; la oficina carga el prospecto **antes** de que exista trabajo.
`LEAD` es además el default del API cuando `status` no viaja.

`COMPLETED` **sí** se ofrece, aunque la tabla del dominio lo marca terminal: cargar
una obra vieja ya terminada es cómo entra al sistema el portafolio de los años
anteriores. Nace cerrada a propósito, y eso es distinto de nacer cancelada.

**Que `CANCELLED` no sea un estado de alta válido no lo exige el servidor**:
`ProjectsService.create` acepta cualquiera de los siete sin llamar a `canTransition`,
así que hoy la regla es una convención que el móvil y el panel repiten sin que
ninguna ficha la respalde. Este spec la escribe en `docs/domain/proyecto.md`, en la
sección de Estados, para que deje de vivir solo en dos formularios.

### El cierre de la obra

`actual_end_date` está en el dominio y `UpdateProjectDto` la acepta, pero un campo
más entre "inicio" y "fin estimado" queda nulo para siempre: nadie vuelve a abrir el
formulario de una obra que ya cerró. **Se pide en el momento en que el dato existe**,
que es al marcarla terminada.

Y ese momento sirve para algo más que capturar una fecha. Es la única vez que alguien
mira la obra completa, así que el diálogo de cierre **es un resumen**: cuánto llevó y
cuánto se desvió de lo previsto.

```
┌─ ¿Marcar la obra como Terminado? ───────────────────┐
│ Una obra terminada no vuelve a cambiar de estado.   │
│ Si todavía queda trabajo, déjela en proceso.        │
│                                                     │
│ Terminó el     [ 2 sep 2026            ▾]           │
│                                                     │
│ Horas          148 h aprobadas · 12 h por aprobar   │
│ Previsto       30 ago · terminó 3 días después      │
│                                                     │
│                        [Cancelar]  [Sí, marcar]     │
└─────────────────────────────────────────────────────┘
```

**De dónde sale cada número, sin endpoint nuevo:**

- **Las horas** salen de `GET /time-entries?projectId={id}`, que ya existe y ya
  filtra por obra. El permiso es `time.read`, y quien puede cerrar una obra tiene
  `projects.write` —OWNER o ADMIN—, que siempre incluye `time.read`.
- **La duración se calcula en el panel**: `clock_out_at − clock_in_at − break_minutes`.
  La entidad no guarda un total, y no es este spec el que se lo agrega.
- **Se suman solo las jornadas cerradas.** Una con `clock_out_at` nulo no tiene
  duración; se cuenta aparte y se avisa, porque una obra que termina con alguien
  todavía fichado es justo lo que conviene ver antes de cerrar.
- **`APPROVED` y `PENDING` van separadas, y `REJECTED` no cuenta.** Un total único
  afirmaría como firme algo que todavía puede cambiar al aprobar.
- **El desvío es resta de fechas contra `target_end_date`**, en el cliente. Si la
  obra no tenía fecha prevista no hay desvío que mostrar, y el resumen lo dice en vez
  de inventar un cero.

**El resumen informa, no bloquea.** Se puede cerrar una obra con jornadas abiertas o
sin aprobar: exigir que estén todas resueltas sería una regla del dominio que ninguna
ficha declara, y este spec no la inventa. Avisar es suficiente.

**Sin dinero.** `pay_rate_cents_snapshot` viaja con `select: false` y no llega al
panel, y está bien que así sea: esto resume tiempo, no costo. Lo que la obra costó es
del frente comercial y tiene su propio spec.

`CANCELLED` también es terminal y también pide confirmación, pero **no lleva resumen
ni fecha de fin**: una obra que se abandona no terminó, y `actual_end_date` afirmaría
que sí.

## Contrato de API

**Ningún endpoint nuevo, ningún DTO tocado, ningún código de error nuevo.**
`openapi.json` no cambia con este spec.

Lo que la pantalla consume, y que ya existe:

```http
GET    /projects                      → lista y ficha
POST   /projects                      → alta
PATCH  /projects/{id}                 → corrección y cambio de estado
GET    /time-entries?projectId={id}   → horas del resumen de cierre
GET    /customers                     → selector de cliente
GET    /customers/{id}/sites          → selector de propiedad
POST   /customers                     → alta en línea, con `site` embebido
POST   /customers/{id}/sites          → propiedad en línea
```

El único error que el panel distingue por código:

```http
PATCH /projects/{id}   { "status": "COMPLETED" }

409 { "code": "PROJECT_INVALID_TRANSITION",
      "message": "Una obra en LEAD no puede pasar a COMPLETED" }
```

Con el selector bien armado no debería aparecer. Se maneja igual, porque **puede
llegar de una carrera real**: dos personas en el panel, o el móvil de un capataz
sincronizando la misma obra. El mensaje dice que la obra ya cambió y recarga la
ficha, en vez de dejar la pantalla afirmando un estado que ya no es.

> `POST /projects` acepta un `id` UUIDv7 del cliente para la idempotencia del móvil
> (regla 19). El panel **no lo manda**: no tiene bandeja de salida ni reintento
> automático, y el servidor genera el id. Es la misma decisión que tomó SPEC-0009.

## Comportamiento sin señal

No aplica: `platform: web`. El panel es de oficina.

Lo que sí se define, igual que en SPEC-0009: **un formulario enviado sin red no
pierde lo escrito**. El error es de conexión, con botón para reintentar, y los
campos quedan como estaban. Reusa `toApiFailure`, que distingue "no hubo respuesta"
de "hubo respuesta con error" mirando `status === 0`; no arma su propia detección.

**Y lo propio de esta pantalla: lo creado en un diálogo no se deshace.** Si alguien
crea el cliente en línea y después el `POST /projects` falla por red, el cliente
**ya existe**. La pantalla no lo borra ni finge que no pasó: conserva la elección
hecha, reintenta solo la obra, y si se abandona el formulario el cliente queda
cargado —que es un resultado correcto, no basura. Deshacerlo sería un borrado que
nadie pidió, y encima uno que SPEC-0009 podría rechazar.

## UI

```
┌─ Obras ────────── [buscar…] [Estado ▾] [+ Nueva obra] ─┐
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────┐ ┌────────────────────────┐  │
│ │ Techo Martinez      🔵 │ │ Baño Nguyen         🟡 │  │
│ │ Martinez Residence     │ │ Nguyen Residence       │  │
│ │ Baltimore · 12 ago     │ │ Silver Spring · 3 sep  │  │
│ └────────────────────────┘ └────────────────────────┘  │
└────────────────────────────────────────────────────────┘

┌─ Techo Martinez ────── [Corregir] [Cambiar estado] ────┐
│  Estado       En proceso                               │
│                                                        │
│  El trabajo   Techos                                   │
│               Reemplazo completo de cubierta…          │
│  Fechas       Inicio 12 ago · Previsto 30 ago          │
│               Terminó 2 sep                            │
│                                                        │
│  Cliente      Martinez Residence            →          │
│  Propiedad    100 Main St, Baltimore MD     →          │
│               El cliente y la propiedad se fijan al    │
│               crear la obra.                           │
└────────────────────────────────────────────────────────┘
```

**El enlace al cliente cuelga de `customers.read`, que no es el mismo permiso que
abre esta pantalla.** `FOREMAN` y `WORKER` tienen `projects.read` y no
`customers.read`: para ellos el nombre del cliente y la dirección se muestran como
texto, sin enlace. Mandarlos a una ruta que el nav ya les esconde y que el API
responde con 403 sería ofrecerles una puerta cerrada. `ACCOUNTANT` sí lo tiene, y
para él el enlace está.

Reusa lo que ya está construido y no inventa una segunda forma de nada:

- **`sl-page`** con sus estados de carga, error y vacío.
- **Las tarjetas de la lista actual**, que ya existen y ya usan `sl-chip` con
  `projectStatusTone`. Los filtros no las reemplazan por una tabla: `data-table` es
  para las pantallas que ya son tabla.
- **`CONFIRM_DIALOG_CONFIG`** para las confirmaciones de estado terminal.
- **`sl-address-field`** con sus container queries, dentro de los dos diálogos.
- **`REQUIRED_IN_WORDS` declarado por pantalla**, nunca en `app.config`: global
  arrastra el chunk de `form-field` al bundle inicial —190 kB— y la pantalla de
  entrada no lo necesita.

Y respeta lo que la guía de estilos ya fijó: **un solo radio** (`--sl-radius-md`),
los controles del `.page__header` a **40px** mientras el formulario se queda en 56,
los **dos temas**, y **cero valores literales** — el token que falte se agrega al
sistema, no se hardcodea.

**Lo obligatorio se dice con palabras en el label**, no con asterisco. Criterio de
SPEC-0006 móvil, ya implementado en el panel.

### El copy sale del móvil

El móvil ya tiene escrito el formulario de obra entero, revisado y en los dos
idiomas. **Se reusa el texto, no el nombre de la clave** — y la diferencia importa,
porque confundirla ya costó tres reescrituras del copy en SPEC-0009.

El `.arb` del móvil usa claves planas con prefijo (`projectFieldName`); el panel usa
**namespace anidado** y sin repetir el prefijo (`projects.name`, `customers.new`,
`action.save`), que es la convención que fijó SPEC-0009 y que ya está en
`apps/web/public/assets/i18n/`. El par exacto lo muestra: el móvil dice
`customerFieldDisplayName` y el panel terminó en `customers.displayName`, con el
mismo string adentro.

Las claves nuevas de esta pantalla van bajo `projects.*`, y toman su **valor** de:

| Panel (nuevo) | Móvil (valor de origen) |
|---|---|
| `projects.fieldName`, `projects.fieldNameHint` | `projectFieldName`, `projectFieldNameHelp` |
| `projects.customer`, `projects.site` | `projectFieldCustomer`, `projectFieldSite` |
| `projects.sitePickCustomerFirst` | `projectFieldSitePickCustomerFirst` |
| `projects.siteNoneForCustomer` | `projectFieldSiteNoneForCustomer` |
| `projects.customerAndSiteFixed` | `projectCustomerAndSiteFixed` |
| `projects.description` | `projectFieldDescription` |
| `projects.serviceType` | `projectFieldServiceType` |
| `projects.startDate`, `projects.targetEndDate` | `projectFieldStartDate`, `projectFieldTargetEndDate` |
| `projects.changeStatus`, `projects.confirmTitle` | `projectChangeStatus`, `projectConfirmTitle` |
| `projects.confirmCompleted`, `projects.confirmCancelled` | `projectConfirmCompletedBody`, `projectConfirmCancelledBody` |
| `projects.confirmAccept` | `projectConfirmAccept` |
| `projects.statusTerminal` | `projectStatusTerminal` |
| `projects.search`, `projects.noMatch`, `projects.noneWithStatus` | `projectsSearchHint`, `projectsEmptySearch`, `projectsEmptyFiltered` |

`projects.status` y los siete `projectStatus.*` ya existen en el panel desde
SPEC-0008: se usan, no se duplican. `projects.status` vale "Estado" y es la misma
palabra que el móvil pone en `projectFieldStatus`, así que **el formulario reusa esa
clave** en vez de agregar una segunda con el mismo texto adentro — que es justo la
deriva que el namespace viene a evitar.

**El resumen de cierre es la excepción: su copy es nuevo.** El móvil no cierra obras
con resumen, así que `projects.closedOn`, `projects.closeHours`,
`projects.closeHoursPending`, `projects.closeOpenShifts`, `projects.closeVsTarget` y
`projects.closeNoTarget` se escriben acá, en los dos idiomas y con la misma voz de
usted. Las horas y los días se formatean por la capa de i18n, nunca concatenando
número y unidad.

La voz es la de usted, que es la del producto. Un texto que diga lo mismo con otras
palabras en cada app es un producto que se lee como dos.

## Criterios de aceptación

- [ ] Crear una obra con cliente y propiedad ya existentes la deja creada y lleva a
      su ficha.
- [ ] **El cliente se crea desde el alta, en diálogo, y vuelve elegido** — con su
      primera propiedad, en un solo envío.
- [ ] **La propiedad se crea desde el alta, en diálogo, y vuelve elegida**, reusando
      `site-dialog`.
- [ ] Un cliente sin propiedades muestra el aviso del móvil y ofrece agregar una; el
      selector de propiedad no queda vacío y mudo.
- [ ] Elegir otro cliente **vacía la propiedad elegida**.
- [ ] Corregir una obra **no ofrece cambiar el cliente ni la propiedad**: los
      muestra como dato, con la frase que dice por qué.
- [ ] El cambio de estado ofrece **solo las transiciones válidas** desde el actual:
      desde `LEAD` aparecen `ESTIMATED` y `CANCELLED`, y ninguna más.
- [ ] Pasar a `COMPLETED` o a `CANCELLED` pide confirmación, con el cuerpo que
      explica que no se vuelve.
- [ ] Una obra en `COMPLETED` o `CANCELLED` muestra el control de estado
      deshabilitado con su razón, no escondido.
- [ ] **Un 409 `PROJECT_INVALID_TRANSITION` recarga la ficha** y dice que la obra ya
      cambió, en vez de dejar la pantalla afirmando el estado viejo.
- [ ] El alta arranca en `LEAD` y **no ofrece `CANCELLED`** como estado inicial.
- [ ] **Cerrar la obra pide la fecha real de fin**, con hoy por default, y la guarda
      en `actualEndDate` en el mismo `PATCH` que el estado.
- [ ] El resumen de cierre muestra **horas aprobadas y por aprobar por separado**, y
      no cuenta las rechazadas.
- [ ] Una jornada **todavía abierta** se cuenta aparte y se avisa, y **no impide**
      cerrar la obra.
- [ ] El desvío contra la fecha prevista se calcula en el panel; una obra **sin
      `targetEndDate`** no muestra un cero, muestra que no había fecha prevista.
- [ ] **Cancelar no pide fecha de fin ni muestra resumen**: una obra abandonada no
      terminó.
- [ ] El resumen **no muestra dinero** — `pay_rate_cents_snapshot` no llega al panel
      y no se pide.
- [ ] **No hay ningún control de borrar obra** en la lista ni en la ficha.
- [ ] Un `ACCOUNTANT` y un `FOREMAN` ven la lista y la ficha y **no encuentran
      ningún control de escritura**: ni "Nueva obra", ni "Corregir", ni "Cambiar
      estado".
- [ ] La búsqueda filtra por nombre de obra y por nombre de cliente, y el filtro por
      estado ofrece los siete más "Todos".
- [ ] **Los tres estados vacíos se distinguen**: no hay obras todavía, ninguna
      coincide con la búsqueda, ninguna tiene ese estado.
- [ ] Un formulario que falla por red conserva lo escrito y ofrece reintentar, y no
      se confunde con un error de validación.
- [ ] **Un cliente creado en el diálogo sobrevive a que la obra falle**: se conserva
      elegido, y el reintento no lo duplica.
- [ ] **Lo mismo con una propiedad creada en el diálogo**: queda cargada en su
      cliente y elegida en el formulario, y el reintento no la duplica.
- [ ] El nombre del cliente y la dirección se muestran **sin enlace** para quien no
      tiene `customers.read`.
- [ ] **Cero cadenas quemadas** (regla 24), en `en` y en `es`, con los textos del
      móvil reusados y las claves bajo `projects.*`, no las planas del `.arb`.
- [ ] Las fechas se formatean por la capa de i18n, nunca concatenando.
- [ ] **Cero valores literales de estilo** y `--sl-radius-md` en todo lo que tiene
      esquinas; los controles del encabezado a 40px.
- [ ] La pantalla se ve correcta en **los dos temas**, incluidos los dos diálogos.
- [ ] Tests del panel para: el alta con cliente y propiedad en línea, el selector de
      transiciones válidas, el filtrado por permiso, y el fallo de red que conserva
      el formulario.
- [ ] `openapi.json` **no cambia**: si cambió, algo se implementó fuera de alcance.

## Riesgos / consideraciones

- **`mat-dialog-content` corta el label flotante del primer campo** si no se le da
  aire arriba. Los dos diálogos del alta empiezan con un campo de texto, así que es
  el caso exacto. Se resuelve en el diálogo, no bajando el label.
- **Los estilos de Material se inyectan después de `styles.scss`.** Gana
  especificidad, no orden: pelearle con el orden de los imports no funciona.
- **No hay reset global de `box-sizing`.** Un `padding` sobre algo con `width`
  desborda, y es fácil de encontrar dentro de un diálogo angosto.
- **Ante cualquier reporte visual: reproducir y medir en el DOM antes de tocar CSS.**
  Las decisiones de diseño que ya se tomaron no se revierten por una impresión.
- **El selector de cliente carga `GET /customers` entero**, sin paginar ni buscar en
  el servidor. Es lo mismo que ya hace la ficha del cliente con `GET /projects`. El
  trigger para bajarlo al servidor es **la primera empresa con más clientes de los
  que entran cómodos en un selector**; anotarlo acá evita que se descubra con datos
  reales.
- **`DELETE /projects/{id}` sigue abierto y es un bypass del invariante de cliente
  que SPEC-0009 metió en la base.** Este spec no lo expone y tampoco lo cierra:
  quedó en [[../../../tech-debt/0014-borrar-obra-sin-comprobacion|DEBT-0014]], con
  el detalle arriba, en "No se borra una obra: se cancela".
- **Un 5xx en `/auth/web/refresh` saca a login.** Está pendiente en
  `session.service.ts` y no es de este spec, pero se cruza acá: pasa a mitad de un
  formulario largo y lo escrito se pierde. Si aparece mientras se implementa, se
  registra; no se arregla de paso.

## ADRs relacionados

- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — el contrato no cambia, y eso se verifica
- [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] — `PROJECT_INVALID_TRANSITION` es el único código que el panel distingue
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — los tokens que la pantalla consume
- [[../../../adr/0013-componentes-angular-material/README|ADR-0013]] — Material como base de los diálogos y los selectores

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-09-03 | en-implementacion | Arranca la implementación, **partida en dos tandas** con el mismo número (regla 25). La primera trae lista con búsqueda y filtro, alta completa con los dos diálogos en línea, y ficha: es lo que desbloquea crear obras desde el panel, que es el punto del spec. La segunda, corrección, cambio de estado y el cierre con resumen |
| 2026-09-02 | aprobado | Tercera pasada: los dos revisores aprueban. `spec-reviewer` verificó los tres bloqueantes de las tres rondas y los seis menores contra el código, no contra lo que el spec afirma — incluido que `payRateCentsSnapshot` no aparece en el schema de `TimeEntry` en `openapi.json`, así que "el resumen no muestra dinero" es comprobable y no una promesa. Listo para implementar |
| 2026-09-02 | review | Segunda pasada de los dos revisores. `domain-guardian` **aprobó**: leer `time_entry` desde la obra es lectura legítima —la relación ya está declarada en las dos fichas—, ningún invariante ata el estado de la obra a que sus jornadas estén cerradas, y `actual_end_date` no es inmutable como el par cliente/propiedad, así que corregirla después no choca con nada. `spec-reviewer` encontró un bloqueante que valía: el `goal` decía "un resumen de lo que **costó**" mientras la sección del cierre excluye el dinero en negrita — en español eso sugiere plata, y el `goal` es contra lo que el revisor de código valida. Se sacó la palabra, acá y en el BOARD. Más dos menores: faltaba `projectConfirmAccept` en la tabla de copy, que `ConfirmData.confirmLabel` exige, y `projects.fieldStatus` habría duplicado el valor de `projects.status`, que ya existe desde SPEC-0008 |
| 2026-09-02 | review | **El cierre de la obra pasa a ser una pantalla, no un campo.** `actual_end_date` no estaba nombrada en el spec y por descarte habría entrado como un campo más del formulario, donde queda nula para siempre: nadie reabre la ficha de una obra que ya cerró. Se pide al marcar `COMPLETED`, y ese momento —el único en que alguien mira la obra entera— trae el resumen de lo que llevó: horas aprobadas y por aprobar, jornadas todavía abiertas, y cuántos días se corrió de la fecha prevista. Sin endpoint nuevo: `GET /time-entries?projectId=` ya existe y `time.read` lo tiene quien puede cerrar. Informa y no bloquea — exigir las horas resueltas sería una regla que ninguna ficha declara. `CANCELLED` queda afuera del resumen: una obra abandonada no terminó |
| 2026-09-02 | borrador | Revisado por `domain-guardian` y `spec-reviewer`. El guardián aprobó y encontró lo que el texto no dejaba ver: `DELETE /projects/{id}` no es la misma deuda que SPEC-0009 cerró, es **una puerta trasera contra ella** — `enforce_customer_no_history` solo mira `project.deleted_at IS NULL`, así que borrar una obra viva por ahí vuelve borrable a un cliente con historia real y cascadea sus propiedades. También marcó que la exclusión de `CANCELLED` en el alta no la respaldaba ninguna ficha, y que el caso de carrera del selector llega como **404, no como el 400** del par cruzado. El revisor de specs encontró dos bloqueantes: el `goal` no cubría listar, buscar ni filtrar —una sección entera de alcance con tres criterios propios—, y la sección de copy listaba las claves planas del `.arb` como si fueran las del panel, que es exactamente lo que costó tres reescrituras en SPEC-0009; el panel usa namespace anidado. Más cuatro menores, todos aplicados |
| 2026-09-02 | borrador | Creado. Segundo tramo de la cadena del panel, después de que SPEC-0009 dejara cliente y propiedad cargables. Tres decisiones al crearlo: **el alta crea cliente y propiedad en línea**, porque irse a Clientes y volver pierde lo escrito y eso es lo que 0009 declaró que hace que alguien deje de usar el panel; **no se expone borrar**, porque el dominio ya tiene `CANCELLED` y un botón de borrar al lado sería el que rompe la regla 12; y **el estado se cambia con su propia acción**, no dentro del formulario, para que corregir una fecha no dispare una transición. El API no abre trabajo: `canTransition` y `PROJECT_INVALID_TRANSITION` ya están implementados y en el contrato |
