---
id: SPEC-0011
title: "Gente, cuadrillas y asignación en el panel"
aliases:
  - "SPEC-0011: Gente, cuadrillas y asignación en el panel"
type: spec
platform: web
status: implementado
goal: "William da de alta a un trabajador desde el panel con su rol y su tarifa, le dicta un código de seis dígitos que el trabajador canjea en la app para elegir su contraseña y activar su membresía, y desde ahí lo suma a una cuadrilla y asigna esa cuadrilla a una obra en una fecha: el trabajador entra y ve esa obra sin que nadie toque la base de datos."
apps:
  - api
  - web
  - mobile
depends_on:
  - "0008-sesion-y-shell"
  - "0002-cuadrillas-y-asignacion"
domain:
  - usuario-y-membresia
  - cuadrilla
  - proyecto
frente: administrativo
created: 2026-09-03
updated: 2026-09-09
tags:
  - spec
  - spec/implementado
  - web
---

# SPEC-0011: Gente, cuadrillas y asignación en el panel

> **Meta**
> - Apps afectadas: `api`, `web`, `mobile`
> - Depende de: [[../0008-sesion-y-shell/README|SPEC-0008]] · [[../0002-cuadrillas-y-asignacion/README|SPEC-0002]]
> - Frente: `administrativo`

---

## Problema

**No existe forma de dar de alta a una persona.** No hay `POST /memberships`, no hay
invitación y no hay registro: los tres usuarios de desarrollo existen porque el seed
los insertó por SQL. Todo lo demás está construido encima de gente que no se puede
crear.

Se descubrió probando: se entró como Carlos, la app dijo que no tiene obra asignada,
y **no había ningún camino para arreglarlo desde la app**. Ni desde el panel.

La cadena entera cuelga de esto:

```
   dar de alta a la persona   ← no existe
        │
        ▼
   sumarla a una cuadrilla    ← el API existe, la pantalla no
        │
        ▼
   asignar la cuadrilla a una obra en una fecha   ← el API existe, project_assignment está vacío
        │
        ▼
   el trabajador abre la app y ve dónde trabaja hoy   ← esto ya funciona, y no llega nunca
```

`crews` está completo en el API desde [[../0002-cuadrillas-y-asignacion/README|SPEC-0002]]
—crear, editar, sumar y sacar miembros con fechas, designar capataz— y **no lo usa
nadie**: el panel lo muestra de solo lectura y el `CrewsClient` generado en Flutter
no lo llama ninguna pantalla. Está construido y desconectado.

Esto es además lo que separa la demo del uso real. Hasta que exista, la app solo la
puede usar quien ya está en la base.

## Alcance

### Entra

**Gente** — el hueco que abre todo lo demás:

- **Alta de una persona**: nombre, teléfono o correo, rol, tarifa por hora y tipo de
  empleo. Crea el `app_user` y la `membership` en estado `INVITED`.
- **Volver a dar de alta a quien se fue y volvió.** El trabajo es de temporada: se van
  en invierno y reaparecen en primavera. Un alta con el contacto de alguien que ya
  tuvo membresía **inactiva** en la empresa la reactiva con un código nuevo —y con el
  rol y la tarifa que traiga el alta, que la temporada siguiente no tienen por qué ser
  los mismos— en vez de chocar contra el `UNIQUE (company_id, user_id)`. Sus horas
  viejas siguen donde están, y su pertenencia terminada a una cuadrilla también.

  **Solo reactiva lo inactivo.** Sobre alguien que ya está `INVITED` —tiene código
  vivo y todavía no lo canjeó— el alta responde `CONTACT_ALREADY_MEMBER` y el panel
  lleva a su ficha ofreciendo generar un código nuevo. Es el camino más largo por dos
  clics y evita el que importa: que volver a teclear a alguien le pise en silencio el
  rol o la tarifa que ya tenía cargados.
- **Un código de seis dígitos** que el alta devuelve una sola vez y William dicta en
  la obra. El trabajador lo canjea en la app, elige su contraseña, y su membresía
  pasa a `ACTIVE`.
- **Regenerar el código**, que es también el camino de "me olvidé la contraseña".
- **Corregir todo lo de esa persona**: nombre, teléfono, correo, rol, tarifa,
  tipo de empleo e idioma. El contacto no es un adorno — **es con lo que entra a
  la app**, así que un teléfono mal tecleado la deja afuera para siempre y sin
  poder corregirlo la única salida sería borrarla y crearla de nuevo.

  Nombre y contacto viven en `app_user`, así que corregirlos alcanza a **todas
  las empresas donde esa persona trabaje**. Es lo correcto —es la misma persona y
  el dato estaba mal en las dos— y la pantalla lo dice antes de guardar, no
  después. El correo y el teléfono son únicos globales: si el nuevo ya es de otro,
  el rechazo llega con `CONTACT_ALREADY_MEMBER`, el mismo del alta.

- **El estado no se elige, se explica.** `INVITED`, `ACTIVE` e `INACTIVE` los
  deriva el acceso: hay código sin canjear, ya canjeó, o se lo quitaron.
  Ofrecerlo como campo sería mentir —nadie está activo antes de entrar— así que
  en la ficha aparece con la frase que dice qué significa y qué hacer.
- **Desactivar** a alguien que se fue: pierde el acceso, conserva sus horas.
- **La tarifa se ve y se escribe solo con `members.manage`** —OWNER y ADMIN—, por un
  endpoint propio y un DTO propio. Fuera de ahí sigue sin existir en el contrato.

**Cuadrillas** — conectar lo que ya está construido:

- Crear y corregir cuadrillas con su nombre, color y capataz.
- Sumar y sacar miembros **con sus fechas**, que es el invariante de la ficha.
- **Ver el nombre de la persona** en las dos pantallas, que hoy el contrato no
  permite. Cierra la mitad de [[../../../tech-debt/0010-listados-sin-la-persona|DEBT-0010]]
  que corresponde a `/crews`.

**Asignación** — el último eslabón:

- Asignar una cuadrilla —o una persona suelta— a una obra **desde una fecha**, y
  marcar cuándo terminó ahí.
- Quitar una asignación cargada por error.
- Ver las asignaciones de una cuadrilla.

**En el móvil**, lo mínimo para que el código sirva:

- Pantalla de canje, alcanzable desde el login, **en dos pasos**: primero el
  código, y una vez comprobado, la contraseña. Escribirla y recién ahí enterarse
  de que el código no servía es hacerle perder el trabajo a quien recién entra.
- Entrar directo al terminar, sin volver a la pantalla de entrada.
- **Ver las obras que todavía no empezaron**, con su fecha y sin poder marcar en
  ellas. Una obra ya asignada que no aparece en ningún lado obliga a preguntar
  por teléfono a dónde se va.

### No entra

- **Invitar por SMS o por correo.** Exige proveedor, su ADR, costo por mensaje y el
  trámite A2P 10DLC de Estados Unidos. El código se dicta en persona, que es como
  William ya coordina con su gente hoy.
- **Cambiar la propia contraseña estando adentro.** Quien la olvida pide un código
  nuevo; quien quiere cambiarla por gusto, todavía no tiene camino y no es lo que
  bloquea el uso real. Es un spec chico y aparte.
- **Pantalla de cuadrilla en el móvil.** El trabajador no necesita ver quién más está
  en su cuadrilla para trabajar: necesita su obra, y eso ya lo resuelve la asignación.
- **El calendario de asignaciones.** Se asigna por fecha desde la ficha de la
  cuadrilla; una vista de semana o de mes es otra pantalla y otro spec.
- **Cuántos trabajadores se planea mandar.** `planned_headcount` existe en la tabla
  desde la primera migración y **hoy no lo lee nadie**: ni un reporte, ni una
  pantalla, ni una consulta que lo compare contra quiénes marcaron entrada. La
  pantalla no lo pide y la columna queda sin escribirse. Un dato que se pide, se
  guarda y nadie mira no es información: es fricción con apariencia de medición, y
  envejece peor que no tenerlo. **Vuelve cuando exista el reporte de planeado contra
  real**, que es quien le da sentido — y ahí se decide si el número lo escribe una
  persona o lo deriva el sistema de los miembros de la cuadrilla.

- **Cambiar de empresa sin cerrar sesión.** Es la mitad abierta de
  [[../../../tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002]] y sigue
  abierta después de esto.
- **Consentimiento firmado de ubicación**, que [[../../../DECISIONES|DECISIONES]]
  registra como pendiente del onboarding del trabajador. Es un texto legal que
  todavía no existe; cuando exista, su lugar natural es el canje.

## Modelo de dominio afectado

- [[../../../domain/usuario-y-membresia|usuario-y-membresia]] — **campos nuevos**, abajo
- [[../../../domain/cuadrilla|cuadrilla]] — sin cambios de modelo
- [[../../../domain/proyecto|proyecto]] — sin cambios de modelo

### El código de invitación vive en la membresía

Tres columnas nuevas en `membership`, no una tabla aparte:

| Columna | Tipo | Notas |
|---|---|---|
| `invite_code_hash` | text | Nulo cuando no hay invitación viva. `select: false` y `@ApiHideProperty()` |
| `invite_expires_at` | timestamptz | Siete días desde que se emite |
| `invite_attempts` | int NOT NULL DEFAULT 0 | Se bloquea a los 10 y solo lo destraba regenerar |

**No es un agregado nuevo.** Hay un solo código vigente por membresía, regenerar
invalida el anterior, y no hace falta historial de invitaciones. La membresía ya
modela este estado: `status = 'INVITED'`, `invited_at` y `joined_at` existen desde la
primera migración y hasta hoy nadie los escribe. El código es lo que le faltaba a ese
estado para ser alcanzable.

Se descartó una tabla `membership_invite` al estilo de `client_access`: esa existe
porque un cliente puede tener varios accesos vivos a la vez —uno por proyecto, uno
general— y hay que poder revocar uno sin tocar los otros. Acá no.

### `app_user.password_hash` pasa a ser nullable

Hoy es `NOT NULL`, y una persona invitada todavía no eligió contraseña. La
alternativa era guardar el hash de un secreto aleatorio que se descarta, y es peor:
deja la base con un valor que parece una contraseña y no lo es, y nada distingue a
quien nunca canjeó de quien sí.

Con la columna nullable se pueden escribir y comprobar dos invariantes:

> **Un `app_user` con `password_hash` nulo no inicia sesión por ningún camino.**

> **La contraseña es del usuario, no de la membresía: no se nulea mientras el usuario
> tenga otra membresía activa que la esté usando.**

El segundo es el que una implementación apurada rompe con un `UPDATE app_user SET
password_hash = NULL WHERE id = …` sin mirar nada más, y el que dejaría a alguien sin
entrar a la empresa donde sí trabaja porque la otra le regeneró un código.

`bcrypt.compare(password, null)` no es una comparación fallida, es un error de tipo,
así que `auth.service.ts:48` se blinda explícitamente antes de comparar. Es la clase
de nulo que se cuela como excepción 500 en vez de como 401.

El segundo cerrojo ya existe y no se toca: `auth_memberships_for_user()` solo
devuelve membresías `ACTIVE`, así que una invitada no resuelve sesión aunque tuviera
contraseña.

### Una persona que trabaja para dos contratistas

Es el ejemplo borde de la ficha, y acá se vuelve concreto. Si el teléfono ya
pertenece a un `app_user`, el alta **no crea otro usuario ni toca su contraseña**:
crea una segunda membresía y su código.

Al canjear ese código, el API mira si la cuenta ya tiene contraseña:

| `password_hash` | Qué pide el canje | Qué hace |
|---|---|---|
| Nulo | Identificador, código y contraseña nueva | La establece y activa la membresía |
| Ya existe | Identificador y código | **No toca la contraseña.** Activa la membresía y avisa que entre con la suya |

**El cuerpo del request no cambia de forma según el caso**: siempre viaja
`identifier`, `code` y `password`. Lo que cambia es qué hace el servidor con el
tercero — establecerlo o ignorarlo—, y así el móvil tiene una sola pantalla en vez de
dos y no necesita saber de antemano si esa persona ya existe en otra empresa.

Sin esa distinción, el contratista B podría emitir un código con el teléfono de
alguien que ya trabaja para A, canjearlo él mismo y quedarse con la contraseña de esa
persona —y con su acceso a la empresa A—. Con ella, lo peor que consigue es activar
una membresía en su propia empresa, que es donde ya manda.

### Regenerar el código es también el camino de la contraseña olvidada

Un trabajador que olvida su contraseña no tiene correo por donde recibir un link. El
mismo mecanismo lo resuelve sin agregar nada: William regenera el código, la
membresía vuelve a `INVITED`, sube `token_version` —que cierra las sesiones vivas de
esa persona en esa empresa— y **si esa es su única membresía, `password_hash` vuelve
a nulo**. La persona canjea de nuevo y elige contraseña.

Si tiene membresías en otra empresa, la contraseña no se toca: canjear solo reactiva.
No hay código de error para eso; el camino se degrada solo.

**Saber si es su única membresía cruza tenants, y no necesita función nueva.**
`auth_memberships_for_user(p_user_id)` ya devuelve las membresías activas de una
persona en todas las empresas, que es exactamente la pregunta: si la única que vuelve
es la que se está regenerando, la contraseña se nulea. Reusarla evita una quinta
`SECURITY DEFINER` y deja el chequeo auditado por donde ya se audita el login.

Regenerar sobre alguien activo lo expulsa, así que el panel lo pide con confirmación
nombrando a la persona.

## Contrato de API

Todo lo de gente cuelga de **`members.manage`** —OWNER y ADMIN—, que está declarado
en `permissions.ts` desde el primer día y **hoy no lo usa ningún endpoint**.

```http
POST   /auth/invite/verify             @Public()       → VerifyInviteDto
GET    /memberships                    members.manage  → MemberDto[]
POST   /memberships                    members.manage  → MemberWithInviteDto
GET    /memberships/{id}               members.manage  → MemberDto
PATCH  /memberships/{id}               members.manage  → MemberDto
POST   /memberships/{id}/invite        members.manage  → MemberWithInviteDto
POST   /memberships/{id}/deactivate    members.manage  → MemberDto

POST   /auth/invite/redeem             @Public()       → AuthResult
```

**`MemberDto` es un DTO propio, no la entity.** `Membership` viaja embebida en
cuadrillas y asignaciones que ven FOREMAN y WORKER, y por eso `pay_rate_cents` está
con `select: false` y fuera del contrato. Un DTO propio deja que la tarifa salga por
el único endpoint que exige `members.manage`, sin abrirla en todos los demás. La
entity no se toca.

```jsonc
// MemberDto
{ "id": "…", "userId": "…", "name": "Carlos Ramírez",
  "email": null, "phone": "+13015550142", "locale": "es",
  "role": "WORKER", "status": "INVITED",
  "payRateCents": 2200, "employmentType": "W2",
  "invitedAt": "…", "joinedAt": null, "inviteExpiresAt": "…",
  "crew": { "id": "…", "name": "Cuadrilla A" }   // la vigente hoy, o null
}

// MemberWithInviteDto — MemberDto + el código, y solo lo devuelven el alta y regenerar
{ "…": "…", "inviteCode": "482915" }
```

**El código se devuelve una sola vez.** En la base vive hasheado, así que no hay
forma de volver a mostrarlo: si se pierde, se regenera. Es el mismo criterio con el
que Backblaze entrega su `applicationKey`, y es el que hace que el hash sirva de algo.

### El canje

```http
POST /auth/invite/redeem
{ "identifier": "301-555-0142", "code": "482915", "password": "…" }

200 → AuthResult, el mismo del login: tokens y membresía
401 { "code": "INVITE_CODE_INVALID" }
401 { "code": "INVITE_CODE_EXPIRED" }
429 { "code": "INVITE_TOO_MANY_ATTEMPTS" }
```

**Pide identificador y código, no solo el código.** Seis dígitos son un millón de
combinaciones y el rate limit de 8/min que ya protege lo público es por IP: con IPs
rotativas, un código suelto es adivinable. Exigir el teléfono obliga a conocer a la
persona antes de empezar a probar.

**El código se hashea con bcrypt, no con sha256.** El portal del cliente hashea con
sha256 y está bien ahí: su token son 32 bytes aleatorios y no hay tabla que
precomputar. Un código de seis dígitos tiene un millón de preimágenes, que se
computan en segundos: quien lea la base los resuelve todos. Bcrypt con el mismo costo
12 de las contraseñas hace la búsqueda impracticable, y el `identifier` es lo que
permite comparar contra una sola fila en vez de contra todas.

**Un intento fallido gasta el contador de todas las invitaciones vivas de esa
persona.** Si alguien tiene invitación abierta en dos empresas a la vez, el servidor
no puede saber cuál de las dos intentaba canjear: sumarle el intento a una elegida al
azar deja la otra sin contar, y esa es fuerza bruta gratis con solo tener una segunda
invitación abierta. Se suman las dos. El costo es un contador desalineado en un borde
raro; el de la alternativa es el bloqueo por intentos convertido en decorado.

**El canje es de un solo uso**: al activar, `invite_code_hash` vuelve a nulo. Un
segundo intento con el mismo código responde `INVITE_CODE_INVALID`, igual que uno
inventado.

`INVITE_CODE_EXPIRED` se distingue de `INVITE_CODE_INVALID` a propósito: la salida es
distinta —pedirle otro a William— y no le enseña nada a quien está probando códigos,
porque para llegar a ese error hay que haber acertado el código.

**Verificar y canjear son dos llamadas, y comparten la resolución del código.**
`verify` comprueba sin consumir, para que la app pueda pedir la contraseña
después. **Un fallo en verify gasta intento igual que el canje**: sin eso sería un
oráculo para probar códigos sin límite, y el corte a los diez quedaría de adorno.

**Un reintento sobre un canje que ya se aplicó no responde error** (regla 19). El
caso que importa no es el de la sección de abajo —sin red, el POST nunca sale— sino
el inverso: la petición llegó, activó la membresía y estableció la contraseña, y la
respuesta se perdió en el camino de vuelta. Con un código de un solo uso a secas, el
reintento diría `INVITE_CODE_INVALID` un segundo después de que la persona eligió su
contraseña, en la única puerta de entrada al producto.

**Se resuelve degradando a login, no con una tabla de idempotencia.** Si no hay código
vivo pero el `identifier` y el `password` del mismo cuerpo resuelven una sesión, se
devuelve el `AuthResult` como si el canje hubiera respondido bien. No abre nada: quien
acierta la contraseña ya podía entrar por `/auth/login`. Y es lo único que funciona
acá — `sync_operation`, el mecanismo de idempotencia que ya existe, tiene
`UNIQUE (company_id, client_id)` bajo RLS, y el canje es anterior a saber la empresa.

Queda un caso sin cubrir, a propósito: quien ya tenía contraseña de otra empresa no
manda `password`, así que su reintento no tiene con qué degradar y recibe
`INVITE_CODE_INVALID`. La app le ofrece ahí mismo entrar con su contraseña, que es lo
que el canje le había dicho que hiciera.

**Cruza tenants, y las dos mitades se marcan** (regla 6). Resolver un código es
anterior al contexto de empresa, igual que el login:

- **Leer** va por una función `SECURITY DEFINER` acotada, con `REVOKE … FROM PUBLIC` y
  `GRANT … TO snapline_app`, como `auth_memberships_for_user()` y
  `client_access_by_token()`. Devuelve `id`, `company_id`, `role`, `invite_code_hash`,
  `invite_expires_at` e `invite_attempts` de las membresías `INVITED` de ese usuario.
- **Escribir** —el intento fallido que incrementa el contador, o la activación— entra
  a `tenants.runAs()` con el `company_id` que esa lectura devolvió. Es el patrón que
  ya usa `logout()` para subir `token_version` sin pasar por el guard, y por eso la
  función tiene que devolver el `company_id` aunque el canje no lo use para nada más.

**Es la cuarta función `SECURITY DEFINER` del sistema, y `tenant.service.ts` pide
discutirlo antes de agregar una.** Discutido: no hay forma de evitarla. `membership`
está bajo RLS desde `EnableRls`, resolver un código exige leerla sin saber la empresa,
y las tres que existen no sirven — `auth_memberships_for_user()` devuelve solo las
`ACTIVE`, que es justo lo que una invitación no es. Ampliarla para que devuelva
también las invitadas sería peor: le cambia la semántica al camino del login, que es
el más sensible del sistema, para servir a otro caso.

El canje entra al grupo de throttle de 8/min que ya tienen login, refresh y el portal:
acepta credenciales sin autenticación previa.

### Cuadrillas: el nombre de la persona

```http
GET  /crews                        → CrewDto[]        · crews.read
GET  /crews/{id}/members           → CrewMemberDto[]  · crews.read
GET  /crews/{id}/assignments       → AssignmentDto[]  · crews.read   ← nuevo
```

`GET /crews` embebe hoy la membresía del capataz **sin su usuario**, así que llega
`foreman.userId` y nunca un nombre. DEBT-0010 proponía extender la relación hasta
`user`; se hace distinto y mejor: un `CrewDto` con `foreman: { membershipId, name }`.
Extender la relación arrastraría correo y teléfono del capataz a una pantalla que ve
cualquier FOREMAN, y el nombre es lo único que la pantalla necesita. Lo mismo para
`CrewMemberDto`, con `name`, `role`, `fromDate` y `toDate`.

Esto **cambia la forma de dos respuestas que ya existen**, así que `openapi.json` se
regenera y los clientes con él (regla 8). El panel las consume; en Flutter el
`CrewsClient` está generado y no lo llama nadie, así que no hay pantalla que romper.

### La asignación es un período, no un día

`work_date date NOT NULL` obligaba a una fila por día: una obra de dos semanas eran
diez filas cargadas a mano, y eso no lo carga nadie. **Pasa a `from_date` + `to_date`
nulo**, la misma forma que la pertenencia a la cuadrilla, y por la misma razón: una
cuadrilla entra a una obra y en algún momento termina su parte; entremedio no hay una
decisión diaria que alguien vaya a registrar.

**El final lo pone una persona.** La obra tiene su fecha estimada de término, pero la
cuadrilla puede irse antes o quedarse después: deducirlo de las fechas de la obra
sería inventar un hecho que nadie atestiguó. Al asignar se propone el inicio de la
obra, que es el dato que ya existe.

**Y arregla una discrepancia entre la ficha y el código.**
[[../../../domain/proyecto|proyecto]] decía que un `WORKER` ve las obras con
asignación **vigente**, y `restrictToAssigned()` nunca miraba la fecha: una asignación
de cualquier día —incluso del año pasado— dejaba la obra visible para siempre. Ahora
vigente significa algo comprobable: `to_date` nulo o posterior a hoy.

Las seis consultas que cruzaban el día con las fechas de la cuadrilla —tres en el API,
tres en el móvil— pasan a solapamiento de períodos. En Postgres con `daterange &&`,
que es el vocabulario que ya usa el `EXCLUDE` de `crew_member`; en SQLite con las
comparaciones equivalentes.

### Asignación

```http
POST   /projects/{id}/assignments                      crews.write     (cambia: fromDate)
GET    /projects/{id}/assignments                      projects.read   (ya existe)
POST   /projects/{id}/assignments/{id}/end             crews.write     ← nuevo, cierra el período
DELETE /projects/{id}/assignments/{assignmentId}       crews.write     ← nuevo, borrado suave
```

**Terminar y quitar no son lo mismo, y las dos existen.** Terminar es un hecho —esa
cuadrilla ya no trabaja ahí desde tal día— y queda en el registro; quitar es corregir
una asignación cargada por error, y es borrado suave.

**Asignar cuelga de `crews.write`, no de `projects.write`**, aunque el endpoint viva
en el controlador de proyectos (`projects.controller.ts:46`). Hoy los dos permisos
habilitan a los mismos roles —OWNER y ADMIN—, así que la diferencia no se nota; el
día que uno de los dos sume un rol, sí. **El borrado nace con el permiso de su POST
hermano**: que quitar una asignación exija menos que ponerla sería un descuadre que
nadie va a notar hasta que importe.

Se agrega el borrado porque cargar una asignación en el día equivocado es el error
más común de esta pantalla, y hoy no hay forma de deshacerlo. Suave, como todo lo que
sincroniza (regla 20).

### Códigos de error nuevos

| Código | Status | Cuándo |
|---|---|---|
| `INVITE_CODE_INVALID` | 401 | Identificador o código que no coinciden, o ya canjeado |
| `INVITE_CODE_EXPIRED` | 401 | El código venció |
| `INVITE_TOO_MANY_ATTEMPTS` | 429 | Diez intentos fallidos sobre la misma membresía |
| `OWNER_ALREADY_EXISTS` | 409 | Alta o cambio de rol a `OWNER` con uno activo |
| `CONTACT_ALREADY_MEMBER` | 409 | Ese teléfono o correo ya tiene membresía **activa o invitada** en esta empresa |

Los rechazos que el panel no necesita distinguir —desactivarse a uno mismo, desactivar
al único OWNER— van con el 409 genérico y su mensaje. El panel no ofrece esos
controles; el API los rechaza igual.

`CONTACT_ALREADY_MEMBER` lo puede tirar el servicio o el `UNIQUE (company_id, user_id)`
de la base, y `OWNER_ALREADY_EXISTS` el servicio o el índice parcial
`uq_membership_single_owner` que ya vive en `IndexesAndInvariants`. **Los cuatro
caminos llegan con el mismo código**, mapeados en `http-exception.filter.ts` (regla 8):
un rechazo que cambia de forma según quién lo atajó es un rechazo que el cliente no
puede tratar.

## Comportamiento sin señal

En el panel no aplica: es de oficina. Vale lo de SPEC-0009 —un formulario que falla
por red conserva lo escrito y ofrece reintentar— y no se arma detección nueva.

**En el móvil, el canje es la única acción del producto que se bloquea sin red, y
está bien que lo haga.** No hay nada que encolar: sin canje no hay sesión, sin sesión
no hay bandeja de salida, y encolar credenciales para mandarlas después es guardar una
contraseña en claro en el dispositivo. Se muestra el error de conexión con su botón de
reintentar y **el código no se consume**.

Esto no toca la regla 9. Marcar asistencia sigue sin poder fallar: quien ya canjeó
tiene su sesión cacheada y el resto del producto funciona igual sin señal. Lo que no
se puede es entrar por primera vez sin red, que es el mismo límite que ya tiene el
login desde [[../../mobile/0001-login-movil/README|SPEC-0001 móvil]].

## UI

El eje **Cuadrillas** ya existe en la navegación, colgado de `crews.read`. Adentro va
en dos pestañas, y **Trabajadores solo aparece con `members.manage`**: el FOREMAN
entra al eje, ve sus cuadrillas y no encuentra la pestaña donde viven las tarifas.

**El vocabulario es el de William, no el del modelo.** En la base son `membership` y
`crew_member`; en la pantalla son **trabajadores**, se **agregan** a la cuadrilla y se
**quitan**. Nada de «gente», «miembros» ni «sumar»: son palabras de programador, y la
primera regla del producto es que se use sin entrenamiento.

```
┌─ Cuadrillas │ Trabajadores ────────── [buscar…] [+ Agregar trabajador] ┐
├──────────────────────────────────────────────────────────────────────┤
│ Carlos Ramírez    Trabajador   $22.00/h   Cuadrilla A    Activo      │
│ Luis Pérez        Encargado    $28.00/h   Cuadrilla A    Invitado    │
│ María Gómez       Trabajador   $20.00/h   —              Sin acceso  │
└──────────────────────────────────────────────────────────────────────┘
```

**Tres estados y se distinguen de un vistazo**, porque cada uno tiene una salida
distinta: *Activo* entra a la app; *Invitado* tiene código vivo y todavía no lo canjeó;
*Sin acceso* es un código vencido o diez intentos fallidos, y lo arregla regenerar.

El alta abre el código en un diálogo, grande y separado por pares:

```
┌────────────────────────────────────────┐
│              (icono)                    │
│      El código de Luis Pérez            │
│                                         │
│           48  29  15                    │
│                                         │
│   Vence el 10 de septiembre             │
│   Dígaselo en persona. No se vuelve     │
│   a mostrar.                            │
│                    [ Copiar ] [ Listo ] │
└────────────────────────────────────────┘
```

Usa el diálogo del panel con la configuración que dejó SPEC-0009 —icono de 72px
arriba, título y cuerpo centrados, 32rem, esquinas de 16px, foco en el diálogo—, no
uno nuevo.

La ficha de la cuadrilla lista sus miembros con el período de cada uno y sus
asignaciones próximas:

```
┌─ Cuadrilla A ──────────────── [Editar] [Asignar a una obra] ─┐
│  Encargado: Luis Pérez                        3 miembros      │
├───────────────────────────────────────────────────────────────┤
│  Trabajadores                            [+ Agregar a la cuadrilla]
│  Luis Pérez      Encargado   desde 1 ago 2026                 │
│  Carlos Ramírez  Trabajador  desde 12 ago 2026                │
│  Pedro Solís     Trabajador  1 – 20 ago 2026        (terminó) │
│                                                               │
│  Asignaciones                                                 │
│  4 sep   Cocina de los Martinez        4 personas          ✕  │
│  5 sep   Baño de los Nguyen            3 personas          ✕  │
└───────────────────────────────────────────────────────────────┘
```

**La pertenencia terminada se ve, no desaparece**: es lo que sostiene que un reporte
de marzo refleje quién estaba en marzo, y esconderla invita a "arreglarla" borrándola.

**Agregar a la cuadrilla pide la fecha de entrada**, con hoy como valor propuesto.
Cuando la base rechaza el solape, el mensaje dice a qué cuadrilla pertenece ese
trabajador en esas fechas, no "conflicto".

**Cada diálogo dice sobre qué está actuando.** «Asignar Cuadrilla A a una obra», no
«Asignar a una obra»: quien lo abre desde la ficha ya sabe dónde está, pero el que
vuelve después de una interrupción, no. Y cada campo dice para qué es —el día es «el
día que esta cuadrilla va a esa obra»—, porque un label suelto que dice «Día» obliga a
adivinar.

**La asignación pide dos cosas: la obra y el día.** Nada más, porque nada más
participa de lo que la asignación decide — qué obras ve ese trabajador en la app, y
por quién puede fichar el capataz ese día.

**Lo obligatorio se dice con palabras en el label**, no con asterisco, como en el resto
del producto.

En el móvil, el canje es una pantalla sola, alcanzable desde el login con "Tengo un
código": identificador, seis casillas y la contraseña nueva con su ojo para mostrarla.
Termina entrando a la app, no volviendo al login.

## Criterios de aceptación

- [x] **Antes de la migración**, la ficha
      [[../../../domain/usuario-y-membresia|usuario-y-membresia]] tiene los tres
      campos nuevos, los dos invariantes del `password_hash` y el caso de las dos
      empresas. En el mismo commit que el esquema, no después: es lo que el esquema
      tiene que respetar, y al revés no sirve de nada.
- [x] Un alta con nombre y teléfono crea `app_user` y `membership` en `INVITED`,
      y devuelve un código de seis dígitos **una sola vez**.
- [x] En la base queda `invite_code_hash` y nunca el código; un `SELECT` sobre
      `membership` no permite reconstruirlo.
- [x] Canjear el código con el identificador correcto activa la membresía, escribe
      `joined_at`, deja `invite_code_hash` en nulo y devuelve tokens que sirven.
- [x] El mismo código, canjeado dos veces, responde `INVITE_CODE_INVALID` la segunda.
- [x] Un código de más de siete días responde `INVITE_CODE_EXPIRED`, y el décimo
      intento fallido bloquea con `INVITE_TOO_MANY_ATTEMPTS` hasta que se regenere.
- [x] **Una membresía `INVITED` no inicia sesión**, aunque se acierte una contraseña:
      el login no la resuelve.
- [x] **`bcrypt.compare` nunca recibe un nulo**: intentar entrar con una cuenta sin
      contraseña responde 401, no 500. Con su test.
- [x] **Un reintento del canje que ya se aplicó devuelve tokens, no
      `INVITE_CODE_INVALID`**: mismo identificador, mismo código, misma contraseña, y
      la persona entra. Es el criterio de la regla 19 para este endpoint.
- [x] **El intento fallido incrementa `invite_attempts` de verdad**: se comprueba
      leyendo la fila, porque un `UPDATE` que no atraviesa RLS no falla, no escribe y
      deja el bloqueo por intentos en decorado.
- [x] Dar de alta a alguien que fue desactivado **reactiva su membresía con un código
      nuevo** y no responde 409. Sus horas y su pertenencia terminada siguen ahí.
- [x] **Emitir un código pone `invite_attempts` en cero**, tanto al regenerar como al
      reactivar por alta. Sin eso, una persona bloqueada queda bloqueada para siempre
      y el único camino de vuelta es un `UPDATE` a mano.
- [x] Un código fallido de alguien con invitación abierta en dos empresas **gasta el
      intento en las dos**, y no deja ninguna sin contar.
- [x] Dar de alta un teléfono que ya es miembro **activo** de la empresa responde 409
      `CONTACT_ALREADY_MEMBER`.
- [x] Corregir el teléfono de alguien ya cargado lo deja **entrar con el nuevo**: es
      el punto de poder corregirlo, y sin eso un dígito mal tecleado obliga a
      borrar y recrear a la persona.
- [x] Poner en alguien el teléfono que ya es de otro responde 409
      `CONTACT_ALREADY_MEMBER`, y dejarlo sin correo **y** sin teléfono se rechaza:
      quedaría sin forma de entrar. Uno que pertenece a **otra** empresa crea la segunda
      membresía sin tocar la contraseña de esa persona, y su canje no la pide.
- [x] Crear un segundo `OWNER` activo responde 409 `OWNER_ALREADY_EXISTS`.
- [x] Regenerar el código de alguien activo lo devuelve a `INVITED`, sube su
      `token_version` —su sesión viva deja de refrescar— y, si es su única membresía,
      deja `password_hash` en nulo.
- [x] Desactivar a alguien le corta el acceso y **no borra ni una hora suya**.
      Comprobado contra la base: marcó entrada, se le quitó el acceso, la hora
      quedó y su login pasó a 401. Intentar borrarla lo impide el trigger
      `time_entry_no_hard_delete` (regla 12).
- [x] `GET /crews` y `GET /crews/{id}/members` devuelven el nombre de la persona y
      **no su correo ni su teléfono**.
- [x] `pay_rate_cents` viaja **solo** en las respuestas de `/memberships`. Un FOREMAN
      que pide cuadrillas y asignaciones no lo recibe por ninguna vía.
- [x] Un FOREMAN entra al eje Cuadrillas y **no encuentra la pestaña Trabajadores**
      —la que trae las tarifas y el contacto—. Verificado en pantalla. Sí entra a
      la **ficha** de su cuadrilla y ve a sus miembros: `/crews/{id}/members`
      devuelve nombre, rol y fechas, sin tarifa ni contacto, y ver a los suyos es
      lo que la ficha de dominio pide.
- [x] Y **solo la suya**: la que lidera o la que integra hoy. `GET /crews` le
      devuelve esa y ninguna más; la ajena responde **404 y no 403**, porque que
      exista es lo que no le toca saber. Quien administra las ve todas. Es la
      misma regla que ya aplicaba el pull, y tiene que serlo: con el REST abierto,
      la app mostraba una cosa u otra según de dónde leyera.
- [x] Sumar a alguien a una segunda cuadrilla con fechas solapadas es rechazado **por
      la base** —`EXCLUDE USING gist`—, y el panel muestra a qué cuadrilla pertenece.
      Comprobado por el endpoint (409) y con un `INSERT` directo, que también rebota.
- [x] Asignar la cuadrilla a una obra en una fecha hace que un WORKER de esa cuadrilla
      **vea esa obra en la app**, y quitarla la saque. Es el arco completo del goal.
- [ ] Regenerar el código de alguien que además trabaja para otra empresa **no le toca
      la contraseña**, y su canje no se la vuelve a pedir.

      **Queda sin verificar a mano a propósito**: hay una sola empresa en la base
      de desarrollo y no existe alta de empresas, así que el caso no se puede
      producir hoy. El invariante está escrito y el camino reusa
      `auth_memberships_for_user()`; se prueba cuando exista el segundo
      contratista, que es el mismo momento que dispara
      [[../../../tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002]].
- [x] La asignación acepta cuadrilla **o** persona, nunca ambas, y quitarla es borrado
      suave.
- [x] El formulario de asignación pide **la obra y el día, y nada más**: ningún campo
      escribe un dato que después no se lea en ningún lado.
- [x] **Cero cadenas quemadas** (regla 24) en panel y móvil, en `en` y en `es`, con la
      misma voz de usted. El copy del móvil se reusa donde ya exista.
- [x] La tarifa se muestra y se escribe por la capa de i18n, en centavos enteros
      (regla 15). Nada de `$` concatenado.
- [x] El teléfono se normaliza a E.164 en el cliente antes de enviarlo, con el mismo
      mecanismo que clientes en SPEC-0009. El canje acepta las tres formas del mismo
      número.
- [x] El canje sin red muestra error de conexión con reintento, **sin consumir el
      código ni un intento**.
- [x] Tests: e2e del arco completo contra Postgres —alta, canje, cuadrilla, asignación,
      el WORKER viendo su obra—, unitarios del vencimiento y el bloqueo por intentos,
      del panel para el filtrado por permiso, y del móvil para el canje.
- [x] `openapi.json` regenerado, con los cinco códigos de error y las dos respuestas
      que cambian de forma (regla 8).
- [x] **Verificar el código no lo consume**: después se canjea igual. Y verificar
      mal **sí gasta intento**, o el bloqueo por intentos no sirve de nada.
- [x] **El pull trae la obra aunque sea vieja.** Lo que cambió es el acceso, no la
      fila: una obra de hace un mes no se toca al asignar a alguien, así que el
      delta por `updated_at` la dejaba afuera y el teléfono recibía la asignación
      **sin la obra, sin su cliente y sin su dirección**.
- [x] Una obra que empieza más adelante **se ve en el móvil con su fecha**, y
      adentro no ofrece marcar: dice desde cuándo se va a poder.
- [x] La migración local **no rompe si la tabla ya está en el esquema nuevo**: se
      pregunta por la columna en vez de suponerla.
- [x] Ninguna asignación se puede quitar con menos permiso del que hizo falta para
      ponerla: crear, terminar y quitar responden 403 al FOREMAN por igual.

## Riesgos / consideraciones

- **Los formularios de este spec no usan la rejilla del panel** — `DEBT-0016`.
  Deuda de cronología: `styles/_form.scss` llegó con Obras y esto se escribió antes.
  Nada se ve roto, todos consumen tokens; lo que falta es cambiar cinco maquetas
  propias por los mixins que ya existen, y tres de las cinco lo necesitan.

- **Seis dígitos es una decisión de usabilidad, no de seguridad.** Lo que la sostiene
  son las tres cosas juntas: el identificador, el vencimiento de siete días y el corte
  a los diez intentos. Si alguna se cae —un vencimiento largo, un contador que no se
  guarda— el código queda adivinable y nada avisa. Los tres tienen su test por eso.

- **Regenerar expulsa.** Es lo correcto cuando alguien perdió el acceso y es un
  accidente caro si se aprieta sobre la persona equivocada: William se queda sin
  cuadrilla a las seis de la mañana. Va con confirmación que nombra a la persona.

- **El alta pide tarifa, y la tarifa se congela al aprobar** (regla 13). Cargarla mal
  el primer día no se arregla cambiándola después: las horas ya aprobadas conservan la
  vieja, que es exactamente lo que la regla protege.

- **`project_assignment` está vacío hoy**, y la visión decide a propósito que la
  bandera del fichaje por otro sea bandera y no bloqueo mientras siga así. Cuando esta
  pantalla haga que la asignación se cargue de rutina, el dato se vuelve confiable y
  endurecerlo pasa a ser posible. **No se endurece acá**, y conviene no hacerlo hasta
  ver que se carga.

- ~~**El pull de `/sync` acota solo al WORKER.** Un FOREMAN sigue bajando todas las
  horas de la empresa con su `pay_rate_cents_snapshot`.~~ **Cerrado dentro de este
  spec**, el 2026-09-07: el pull acota ahora también al FOREMAN —sus obras, sus
  asignaciones, sus cuadrillas— y `pay_rate_cents_snapshot` va con `select: false` y
  `@ApiHideProperty()` para todos, así que no baja por esa vía para nadie. Lo que el
  teléfono guarda en disco es lo que la puerta REST le concede, que era el punto.

- **La migración cambia `password_hash` a nullable sobre una base con datos.** Los
  usuarios del seed tienen contraseña y no se tocan; lo que hay que verificar es que
  ningún camino de login trate el nulo como cadena vacía.

## ADRs relacionados

- [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] — los cinco códigos nuevos
- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — los DTOs propios en vez de la entity

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-09-09 | implementado | **PR #45 mergeado.** Los 37 criterios comprobados; el que queda sin marcar es el aislamiento entre contratistas, que exige un segundo contratista y hoy todavía no se puede crear — queda escrito arriba con su razón, no tachado. `code-reviewer` cerró en LISTO PARA PR a la tercera pasada. Al traer `main` aparecieron dos choques de numeración con Obras en el panel, que se mergeó primero y se queda con los números: este spec pasó de 0010 a **0011** y su deuda de 0014 a **DEBT-0015**; el `SPEC-0010` de móvil no se tocó, que la numeración es por track. API 110 unitarios y 95 e2e, panel 92, móvil 438 |
| 2026-09-09 | en-implementacion | **El capataz ve su cuadrilla y ninguna otra**, decidido por @jaca sobre la pregunta que dejó abierta el revisor. `crews.read` incluye al FOREMAN, así que el scope por rol **es** el control de acceso de estas cuatro rutas: sin él, el REST le entregaba la empresa entera —quién está en cada cuadrilla, con qué fechas— mientras el pull ya se lo negaba, y la app mostraba una cosa u otra según de dónde hubiera leído. La regla no se inventó: es la de `cuadrillaVisible` del pull, **la que lidera o la que integra hoy**, copiada tal cual. La cuadrilla ajena responde **404 y no 403**, porque que exista es lo que no le toca saber. Alcanza a `GET /crews`, a la ficha, a los miembros y a las asignaciones, y por defensa también a las escrituras que hoy el guard ya le niega. Dos e2e nuevos: la suya y solo la suya, y la que integra sin liderarla. De paso quedó una nota del spec al día: decía que el pull acota solo al WORKER, y este spec ya lo había acotado al FOREMAN. API 106 unitarios y 95 e2e |
| 2026-09-07 | en-implementacion | **Segunda pasada de `code-reviewer`: LISTO PARA PR, con dos MEDIO que se cerraron.** El primero destapó algo peor que lo que reportaba: el revisor marcó que el mensaje del solape se mostraba **tal como venía del servidor**, en español, al único usuario que administra en inglés. Al escribir el test para arreglarlo resultó que **ese mensaje nunca existió**: `cuadrillaQueChoca()` consultaba dentro del `catch`, y cuando la exclusión de la base salta, Postgres aborta la transacción entera —el request corre dentro de una—, así que la consulta fallaba y se llevaba puesto el error bueno. Lo que llegaba era «La operación viola una restricción de datos», el genérico. **Se pregunta antes de insertar**; la exclusión sigue siendo la que manda para dos altas simultáneas, sin nombre porque a esa altura ya no se puede consultar. El nombre viaja ahora en `details` y no dentro de la frase, que es lo que ADR-0011 pide desde el principio, y la frase la arma el panel. Barrido: no quedaba ninguna otra consulta adentro de un `catch` en todo el API. El segundo MEDIO era una ausencia de señal —los tres endpoints de asignación declaran el mismo `crews.write` y nada lo probaba—, y ahora un e2e con token de capataz los recorre. Tres tests nuevos: el solape con su `details`, el 403 de los tres endpoints, y el diálogo que traduce en vez de repetir al servidor. API 106 unitarios y 93 e2e, panel 65, móvil 438 |
| 2026-09-07 | en-implementacion | **Los siete hallazgos de `code-reviewer`, cerrados.** El que más pesaba no se veía leyendo: el selector de asignar filtraba por un estado **que no existe** —`ESTIMATING`—, así que una obra estimada nunca aparecía y nadie recibía un error; los nombres del enum viven ahora en `isOpenProject()` y no escritos a mano en cada pantalla. Los demás: `EndCrewMemberDto` en vez de un cuerpo sin declarar, el rechazo de quedarse sin contacto comparado contra **lo que queda en la fila** y no contra lo que vino en el cuerpo —mandar solo `{phone: null}` sobre alguien sin correo lo dejaba sin forma de entrar—, `app_user_needs_contact` mapeado en el filtro, el choque de cuadrillas que ahora **nombra la otra cuadrilla** con `CREW_MEMBER_OVERLAP`, `plannedHeadcount` fuera de `CrewAssignmentDto`, y la paleta en `core/brand/crew-colors.ts`. Y el hallazgo que era una ausencia: **Cuadrillas no tenía un solo test**. Van tres sobre lo que el spec promete —que el capataz no pide las tarifas y que `crews.write` gobierna el alta—, y la suite del panel queda en 63. **Un flake que el ojo no explicaba y el reloj sí**: dos e2e tomaban su cursor de `since` con `new Date()` de Node, que en esta máquina corre **un milisegundo adelante** del reloj de Postgres —medido—, así que `updated_at > cursor` daba falso cuando la escritura caía en el mismo milisegundo. El cursor sale ahora del `serverTime` del pull, que es lo que hace el móvil y lo que ese mismo docblock ya advertía. Seis corridas seguidas en verde donde antes fallaban cuatro de ocho |
| 2026-09-07 | en-implementacion | **Cerrado en verificación.** De los cinco criterios que pedían ojo humano, cuatro quedaron comprobados: el solape lo rechaza la base con un `INSERT` directo, quitar el acceso deja las horas —y borrarlas lo impide el trigger de la regla 12—, poner y quitar una asignación piden el mismo permiso, y el capataz no encuentra la pestaña de tarifas. **Queda uno solo sin probar y se explica por qué**: exige un segundo contratista que hoy no se puede crear. Probándolo aparecieron dos arreglos más: en la app, el capataz sin obra hoy **no veía a su gente** —la pantalla colgaba de la obra y no de la cuadrilla, cuando la ficha de dominio pide justo lo contrario—; y en el panel, la ficha pedía una URL vacía que resolvía a la raíz del API, **un 404 por carga** para quien no tiene `members.manage`, mientras el buscador prometía filtrar por datos que ese rol no puede leer |
| 2026-09-07 | en-implementacion | **Cuatro cosas salidas de probarlo en el simulador, y tres eran bugs de verdad.** (1) **La migración local rompía la app al abrir**: daba por hecho que la tabla tenía `work_date` y en un teléfono real ya había nacido con `from_date`, así que la base no abría y el sincronizador fallaba en cada intento. Es el mismo bicho que ese archivo ya documentaba para la v6 —`createTable` usa el esquema de hoy— y no lo apliqué a la mía. (2) **El pull incremental no traía la obra al asignar**: `updated_at > desde` deja afuera una obra vieja aunque el acceso sea nuevo, así que bajaba la asignación huérfana. El delta incluye ahora lo que recién se hace visible, con su cliente y su propiedad. (3) **El canje pasa a dos pasos**, con `POST /auth/invite/verify` que comprueba sin consumir y gasta intento si falla. (4) Y lo pedido: **las obras por empezar se ven**, con su fecha y sin marcar. Además, el copy del canje deja de explicar el producto —«su jefe le da un código» era una frase de manual— y falta de `RefreshIndicator` en Obras, que Clientes y Proyectos ya tenían. Quedó registrado **DEBT-0015**: el banner dice «sin conexión» ante cualquier fallo del sincronizador, y en este caso mintió dos veces |
| 2026-09-06 | en-implementacion | **La pantalla de canje en el móvil, que era lo último que faltaba.** Identificador, seis dígitos y la contraseña que va a usar; se llega desde el login con «Tengo un código». Obligó a un cambio en `ApiFailure`: **no leía el `code` del envelope**, así que un código vencido y uno equivocado eran el mismo 401 en pantalla —y lo que hay que hacer con cada uno es lo contrario, pedirle otro al jefe o revisar los dígitos—. Ahora ramifica sobre el código estable (ADR-0011) y nunca sobre el status. El campo del código acepta solo dígitos y teclado numérico: se dicta en voz alta y se escribe con guantes. 432 tests del móvil, ocho nuevos |
| 2026-09-06 | en-implementacion | **Se abre la corrección al nombre y al contacto**, que yo había dejado afuera leyendo el alcance al pie de la letra —«corregir rol, tarifa y tipo de empleo»— sin ver el caso que lo rompe: **el contacto es con lo que la persona entra a la app**, así que un teléfono mal tecleado la deja afuera para siempre y la única salida era borrarla y recrearla. Abre trabajo de API: `PATCH /memberships/:id` toca ahora también `app_user`, con el choque de unicidad mapeado a `CONTACT_ALREADY_MEMBER` y el rechazo de quedarse sin correo **y** sin teléfono. Y como esos campos son del usuario, corregirlos alcanza a las demás empresas donde trabaje: la pantalla lo dice en el hint, antes de guardar. **El estado quedó explicado y no editable**, que era la otra pregunta: `INVITED` no es una opción que alguien elija, es que todavía no canjeó su código |
| 2026-09-05 | en-implementacion | **La asignación pasa de un día a un período**, por preguntar qué era ese «día de trabajo». Era un día suelto, con una fila por día: dos semanas de obra, diez filas a mano. El modelo mental correcto salió del negocio y no del esquema — la obra ya tiene sus fechas, así que lo único que hace falta decir es **cuándo entra la cuadrilla**, y el final se marca cuando llega. `work_date` pasa a `from_date` + `to_date` nulo, igual que la pertenencia a la cuadrilla. En el camino apareció una **discrepancia entre la ficha y el código**: `proyecto.md` prometía que el trabajador ve las obras con asignación *vigente* y `restrictToAssigned()` nunca miraba la fecha, así que una asignación de cualquier día la dejaba visible para siempre. Toca seis consultas —tres del API, tres del móvil—, la tabla local con su migración a v10, y el `columnTransformer` que hace que el día viejo sobreviva como fecha de entrada. 424 tests del móvil, 106 unitarios y 86 e2e |
| 2026-09-04 | en-implementacion | **Sale «cuántos trabajadores va a mandar», por preguntar para qué servía.** Yo lo había defendido diciendo que era contra lo que se comparan los que marcaron entrada; al ir a comprobarlo, **esa comparación no existe en ninguna parte del producto**: `planned_headcount` se escribe y no lo lee ni un reporte, ni una pantalla, ni una consulta, y en el móvil solo es una columna de la tabla local sin uso. La justificación era mía, no del código. El campo sale del formulario y la columna queda en la base sin escribirse, hasta que exista el reporte de planeado contra real |
| 2026-09-04 | en-implementacion | **Corrección de vocabulario, pedida al probarlo.** La pantalla hablaba como el modelo y no como William: «Gente» por trabajadores, «Sumar a alguien» por agregar a la cuadrilla, «Miembros», «Quién». Queda escrito arriba como criterio y no solo como cadenas cambiadas, porque es el tipo de cosa que vuelve sola en la próxima pantalla. En el diálogo de asignación faltaba además **sobre qué se está actuando** —ahora nombra la cuadrilla— y **para qué es cada campo**: el día no decía que es el día que la cuadrilla va a esa obra, y «cuántos van» no decía contra qué se compara. Ese número pasa a venir prellenado con los trabajadores de la cuadrilla: el caso normal es que vayan todos |
| 2026-09-04 | en-implementacion | **Panel completo y probado en el navegador.** El eje Cuadrillas con sus dos pestañas —Gente cuelga de `members.manage`, así que un FOREMAN no la encuentra—, el alta con su diálogo de código, regenerar, quitar el acceso, y la ficha de la cuadrilla con miembros y asignaciones. La suite del panel queda en 60 y **ninguno es de Cuadrillas**: lo escrito acá se verificó en el navegador, no con tests. **Tres correcciones que salieron de mirar la pantalla, no de los tests**: la columna de estado se titulaba «Activo» en vez de «Estado» porque reusé la clave del valor; los labels traían el asterisco de Material en vez de decir «(obligatorio)» con palabras, que es la convención que fijó el móvil; y los conteos decían «1 cuadrillas». **Y un bug preexistente que este spec destapó**: `DatePipe` leía un `date` de Postgres como medianoche UTC, así que toda fecha sin hora se mostraba **un día antes** en cualquier huso al oeste de Greenwich — la asignación de hoy aparecía como ayer. Toca también las fechas de Proyectos. Arreglado en el pipe, con sus tests |
| 2026-09-04 | en-implementacion | **API completo.** La migración con las tres columnas y `password_hash` nullable, la cuarta función `SECURITY DEFINER`, los seis endpoints de gente, el canje, los DTOs de cuadrilla que cierran la mitad de DEBT-0010 y el borrado de asignación. 106 unitarios y 86 e2e, con nueve tests nuevos del canje y ocho del arco completo contra Postgres. **Un bug lo encontró el test, no la lectura**: crear un segundo OWNER pasaba sin ruido, porque `uq_membership_single_owner` solo cubre el estado `ACTIVE` y una membresía nace `INVITED` — el choque habría aparecido recién al canjear, en la cara del trabajador. Se cierra en el servicio, para el alta y para el cambio de rol. Falta el panel y la pantalla de canje del móvil |
| 2026-09-03 | aprobado | Aprobado por @jaca. Arranca en `feature/SPEC-0011-gente-y-cuadrillas`, **por el API**: la ficha de dominio y la migración primero, porque el panel no puede probar ni el canje ni el bloqueo por intentos hasta que el esquema exista |
| 2026-09-03 | review | **APROBADO por los dos revisores** en la segunda pasada, con los cuatro bloqueantes cerrados y verificados contra el código, no contra el texto del spec. Se cerraron además sus cuatro menores: el cuerpo del canje tiene forma fija y lo que cambia es el uso del `password`; un alta sobre alguien ya `INVITED` responde `CONTACT_ALREADY_MEMBER` y el panel ofrece regenerar, en vez de pisarle en silencio el rol y la tarifa; un intento fallido gasta el contador de **todas** las invitaciones vivas de esa persona, porque sumárselo a una sola deja fuerza bruta gratis a quien tenga una segunda invitación abierta; y emitir un código pone el contador en cero, que si no deja a un bloqueado sin camino de vuelta |
| 2026-09-03 | borrador | Revisado por `domain-guardian` y `spec-reviewer`, los dos con CAMBIOS REQUERIDOS y los dos apuntando al mismo bloqueante: **el canje no cumplía la regla 19**. El caso cubierto era el fácil —sin red, el POST nunca sale— y faltaba el que rompe: la petición llega, activa la membresía y la respuesta se pierde, así que el reintento decía «código inválido» un segundo después de que la persona eligió su contraseña, en la única puerta de entrada al producto. Se resuelve **degradando a login**, no con tabla de idempotencia: `sync_operation` tiene `UNIQUE (company_id, client_id)` bajo RLS y el canje es anterior a saber la empresa. El revisor de specs encontró además un **error de hecho**: la tabla afirmaba que asignar cuelga de `projects.write` y el código usa `crews.write`, y sobre esa base el DELETE nuevo nacía con un permiso distinto al de su POST hermano. El guardián marcó que la **escritura** del contador de intentos también es anterior al contexto de tenant y no tenía mecanismo declarado —va por `runAs()` con el `company_id` que devuelve la lectura, como `logout()`—, y que `tenant.service.ts` pide discutir toda cuarta función `SECURITY DEFINER`: queda discutida. Entra también la **reactivación de quien se fue y volvió**, que el trabajo de temporada garantiza y que el `UNIQUE (company_id, user_id)` habría rechazado con un 409 sin explicación |
| 2026-09-03 | borrador | Creado. Sale de [[../../../PENDIENTES|PENDIENTES]]: se entró como Carlos, la app dijo que no tiene obra asignada y no había camino para arreglarlo. Tres decisiones tomadas al escribirlo: el acceso es un **código de seis dígitos dictado en persona** —no SMS, que arrastra proveedor y trámite A2P—, la **asignación a la obra entra** porque sin ella dar de alta gente no desbloquea nada, y la **tarifa se carga en el alta** porque aprobar horas sin tarifa congela un nulo. Arrastra la deuda declarada de `crews`, que se construyó sin spec |
