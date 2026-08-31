---
id: SPEC-0008
title: "Sesión y shell del panel"
aliases:
  - "SPEC-0008: Sesión y shell del panel"
type: spec
platform: web
status: en-implementacion
goal: "William entra al panel desde el navegador, ve solo los ejes que su rol habilita, al recargar sigue adentro sin que el refresh token haya estado nunca al alcance de JavaScript, y cuando cierra sesión ese token deja de servir."
apps:
  - api
  - web
depends_on:
  - "0007-cimientos-visuales"
domain:
  - usuario-y-membresia
  - empresa
frente: plataforma
created: 2026-08-30
updated: 2026-08-31
tags:
  - spec
  - spec/en-implementacion
  - web
---

# SPEC-0008: Sesión y shell del panel

> **Meta**
> - Apps afectadas: `api`, `web`
> - Depende de: [[../0007-cimientos-visuales/README|SPEC-0007]]
> - Frente: `plataforma`

---

## Problema

El API tiene 78 operaciones y ningún consumidor web.

Eso deja el ciclo de [[../../../product/vision|la visión]] partido por la mitad. El
móvil captura la foto y la etiqueta, el API sabe publicarla, y **entre las dos cosas
no hay nadie**: el paso "William aprueba qué se muestra" no tiene superficie. Nadie
llama a `POST /projects/{id}/publish` desde ninguna interfaz — el cliente Dart está
generado y sin usar.

Este spec no construye ese paso. Construye lo que **toda** pantalla del panel
necesita antes de poder existir: entrar, saber quién sos y en qué empresa, y a dónde
podés navegar. [[../0007-cimientos-visuales/README|SPEC-0007]] resolvió cómo se ve;
esto resuelve quién entra y qué encuentra.

Es también la fase 1 del [[../../../product/roadmap|roadmap]] —el núcleo
administrativo— que es lo que se le factura a William.

Y trae una cosa que el sistema no tiene todavía y que el panel vuelve necesaria:
**cerrar sesión hoy no puede invalidar nada**. El refresh es un JWT sin estado, así
que "salir" solo significa que el cliente borró su copia. En el teléfono, que es de
una sola persona, eso alcanza; en una computadora, no.

## Alcance

### Entra

**Sesión**

- Login con **un solo campo de identificación** que acepta teléfono o email sin que
  el usuario elija cuál escribe — mismo criterio que
  [[../../mobile/0001-login-movil/README|SPEC-0001 móvil]], por la misma razón de
  dominio: `email` y `phone` son opcionales y basta uno.
- **El access token vive en memoria y el refresh en una cookie `httpOnly`**
  ([[../../../adr/0014-sesion-web-en-cookie/README|ADR-0014]]). Tres endpoints nuevos
  en el API, detallados abajo.
- Refresh silencioso: al recargar la página y cuando el access vence.
- Interceptor que adjunta el bearer y traduce los errores de
  [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] por su `code`.
- Cierre de sesión que **invalida el refresh de verdad**, no solo borrando la cookie:
  entra `membership.token_version`, sin el cual un refresh capturado antes del logout
  seguiría valiendo 30 días. Es el único campo nuevo del spec y está detallado abajo.

**Shell**

- Navegación lateral **dibujada desde `membership.permissions[]`**, que ya viaja en
  la respuesta del login. La tabla de roles no se replica en Angular.
- Un destino por eje, cada uno con una **lista sintética scrolleable**: sin eso no
  se puede verificar que navegar entre ejes conserve el estado. Es el mismo criterio
  que [[../../mobile/0003-arquitectura-de-navegacion/README|SPEC-0003 móvil]] fijó y
  que ahí funcionó.
- El panel arranca en `user.locale`, y cambiar el idioma desde la interfaz lo
  persiste con `PATCH /auth/me/locale`. SPEC-0007 dejó a Transloco arrancando en el
  idioma del navegador; acá lo gana el usuario.

### No entra

- ~~**El contenido real de cada pantalla.** Cada eje es un placeholder; proyectos,
  clientes, facturación, reportes y publicación llevan cada uno su spec.~~
  **Entró el 2026-08-31, por decisión explícita.** Las listas sintéticas se veían
  como andamiaje y no dejaban juzgar el shell, así que los ocho ejes leen los
  endpoints que ya existen: `/projects` en tarjetas y los otros siete en tabla,
  con carga, error y vacío. **Lo que sigue sin entrar es escribir**: no hay un
  solo formulario ni una sola mutación, y cada eje sigue necesitando su spec para
  eso. El detalle de por qué está en el historial.
- **Registro y recuperación de contraseña.** No hay endpoint, y el dominio define
  que las cuentas las crea el admin invitando. Igual que en móvil.
- **Selector de empresa.** `memberships[]` viaja en el login, pero no existe endpoint
  para cambiar de membresía sin re-login — es
  [[../../../tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002]].
- **Subir fotos desde el navegador, y las reglas de CORS del bucket que eso exige.**
  Estaban acá y salieron: son un paso manual en la consola de Backblaze que no aporta
  a "quién entra y qué encuentra", y no tiene sentido que su configuración bloquee un
  PR de sesión. Siguen anotadas en [[../../../PENDIENTES|PENDIENTES]], con el trigger
  corregido a la primera pantalla que suba una foto — que es cuando de verdad hacen
  falta, no cuando arranca `apps/web`.
- **SSR.** El panel es privado y va detrás de login; no tiene nada que indexar.
- **Biometría, recordar dispositivo, o cualquier segundo factor.** No hay queja real
  que lo pida.

## Modelo de dominio afectado

- [[../../../domain/usuario-y-membresia|usuario-y-membresia]]
- [[../../../domain/empresa|empresa]]

No introduce agregados nuevos. **Sí introduce un campo:** `membership.token_version`,
un entero que arranca en 0.

### Por qué hace falta

El refresh es un **JWT autofirmado y sin estado**: `refresh()` en `auth.service.ts`
solo hace `jwt.verifyAsync()`. Una vez emitido vale 30 días y el servidor no tiene
dónde anotar que ya no sirve — no hay tabla de sesiones, ni `jti`, ni denylist. Los
únicos `revoked_at` del sistema son de `client_access`, que es el portal del cliente
y otro camino entero.

Sin este campo, *"cerrar sesión"* solo puede significar "el navegador borró su
cookie", y un refresh capturado antes sigue valiendo un mes.

### Cómo funciona

```
issue()    ─▶ el claim lleva membership.token_version
logout     ─▶ UPDATE membership SET token_version = token_version + 1
refresh()  ─▶ (claim.tv ?? 0) == membership.token_version ?
                   └─ no ─▶ 401 TOKEN_INVALID
```

**El `?? 0` no es defensivo, es lo que evita expulsar a todo el mundo el día del
deploy.** `AccessTokenPayload` hoy no tiene `tv`, así que ningún token ya emitido lo
lleva: con una comparación estricta, `undefined === 0` da `false` y **toda sesión
viva del móvil se cae en el primer refresh**. Tratando el claim ausente como versión
0, un token viejo compara `0 === 0` y sigue andando; a partir de ahí todos los nuevos
llevan el claim explícito y el mecanismo funciona como está descrito.

Lo escribe el servidor y **nunca se acepta del cliente**. Eso ya está cubierto sin
código nuevo: `main.ts` monta `ValidationPipe({ whitelist: true })`, así que un
`token_version` en el body de login o refresh se descarta solo.

### Dos cosas que la migración arrastra

**`auth_memberships_for_user()` tiene que devolver el campo.** Es la función
`SECURITY DEFINER` que es el único camino sancionado para leer `membership` sin
contexto de tenant, y hoy devuelve `id, company_id, role, pay_rate_cents`. `refresh()`
necesita `token_version` justo ahí, antes de tener tenant. Se extiende con
`CREATE OR REPLACE` **en la misma migración que agrega la columna**: si no, la
tentación es escribir una query sin scope por fuera del `runUnscoped()` documentado.

**El campo se trata como `pay_rate_cents`**: `select: false` y `@ApiHideProperty()`
en la entity. Hoy no hay fuga —los DTO de salida mapean campo a campo y no serializan
la entity— pero es el mismo patrón de "solo servidor" que la tarifa ya resolvió, y
dejarlo sin blindar invita a que el primer DTO que serialice la entity lo publique.

### La consecuencia que hay que decidir a conciencia

**Vive en la membresía, así que invalida por membresía y no por dispositivo.**
Cerrar sesión en el panel también tira la sesión del teléfono de esa misma persona
en esa misma empresa. Para William, que administra desde la computadora y usa la app
en la obra, eso se siente como un bug aunque sea el comportamiento correcto del
mecanismo.

Separarlas exige una tabla de sesiones con un registro por dispositivo, que es un
agregado nuevo y bastante más trabajo. **Este spec no la construye**: queda registrado
en [[../../../tech-debt/0008-logout-invalida-por-membresia|DEBT-0008]], con el trigger
puesto en la primera queja real.

`domain-guardian` lo revisó y confirmó que `membership` es el lugar correcto — en
`app_user` sería peor, porque cerrar sesión en una empresa invalidaría también la
sesión de esa persona en otra.

## Comportamiento sin señal

No aplica: `platform: web`. El panel es de oficina y la regla 9 —marcar asistencia
nunca puede fallar— es del móvil, que es donde se ficha.

Lo que sí se define es que **una recarga no expulsa a nadie**. Si el refresh
silencioso falla por red y no por credenciales, el panel lo dice como problema de
conexión y ofrece reintentar; no manda a la pantalla de login, que haría creer que la
sesión venció.

Y que **un fallo de transporte no se muestra como error de credenciales**. Sin red no
hay respuesta HTTP, así que tampoco hay `code` de ADR-0011 que traducir: el
interceptor tiene que distinguir "no hubo respuesta" de "hubo respuesta con error"
antes de buscar el código. Aplica a las dos entradas —el refresh silencioso y el
login manual— y en las dos el mensaje es de conexión, con el botón para reintentar.

## Flujo de usuario

```
William abre el panel
   │
   ├─ hay cookie de refresh ──▶ POST /auth/web/refresh ──▶ entra directo
   │                                    │
   │                                    ├─ falla por red ───▶ "sin conexión", reintentar
   │                                    └─ falla por token ─▶ login
   │
   └─ no hay cookie ──▶ login (identificador + contraseña)
                          │
                          ▼
                  access token ──▶ memoria
                  refresh token ─▶ Set-Cookie httpOnly, 30 días
                  user.locale ───▶ idioma del panel
                  permissions[] ─▶ ejes visibles del shell
                          │
                          ▼
                     shell con su navegación
```

## Contrato de API

El móvil sigue con bearer y su contrato **no se toca**: `AuthResultDto` es lo que ya
consume, y hay trabajo en vuelo sobre esos modelos Dart. Por eso el camino de web es
suyo propio en vez de un flag sobre los endpoints existentes — cada cliente tiene su
contrato explícito y `openapi.json` documenta los dos sin ambigüedad. La alternativa
descartada y su costo están en ADR-0014.

Los tres delegan en el mismo `AuthService`; no se duplica lógica de autenticación.

```http
POST /auth/web/login
{ "identifier": "william@…", "password": "…" }

200 OK
Set-Cookie: sl_refresh=…; HttpOnly; Secure; SameSite=Strict;
            Path=/api/auth/web; Max-Age=2592000
{ "accessToken": "…", "expiresInSeconds": 3600, "user": {…},
  "membership": {…}, "memberships": [ … ] }
```

**El `refreshToken` no aparece en el cuerpo.** Es el punto entero de la decisión: si
viaja en el body, un XSS lo lee de la respuesta y la cookie no protegió nada.

**Eso exige un DTO propio, `WebAuthResultDto`, y no reusar `AuthResultDto`.** El del
móvil declara `refreshToken!: string` como obligatorio: satisfacerlo devolviendo una
cadena vacía dejaría el campo en `openapi.json` como siempre presente, que es
exactamente lo que la decisión evita. El resto de los campos se comparten.

```http
POST /auth/web/refresh     ← la cookie viaja sola, sin body

200 OK   → mismo cuerpo que login, con un accessToken nuevo
401      → { "code": "TOKEN_INVALID" }  cookie ausente, vencida,
                                        o con token_version viejo
```

```http
POST /auth/web/logout      ← la cookie viaja sola, sin body

204 No Content
Set-Cookie: sl_refresh=; HttpOnly; Secure; SameSite=Strict;
            Path=/api/auth/web; Max-Age=0
```

Es idempotente: llamarlo sin cookie, o dos veces, responde 204 igual. No hay nada
que informarle a quien ya está afuera.

**El claim del token lleva `token_version`**, y `refresh()` lo compara contra el de
la membresía antes de emitir nada. Un token con la versión vieja se rechaza aunque
su firma sea válida — que es la única forma de que un JWT sin estado deje de servir
antes de vencer.

Lo que esto arrastra en el API:

- **`Max-Age=2592000`**, los mismos 30 días que vive el refresh JWT. Sin ese
  atributo sería cookie de sesión y moriría al cerrar el navegador, que es una
  decisión distinta a la que se tomó.
- **`expiresInSeconds` es 3600**, el `ACCESS_TOKEN_TTL_SECONDS` que ya usa el
  servicio. No se define uno propio para web.
- CORS con `credentials: true` y origen explícito. **Nunca `*`** — con credenciales
  el navegador lo rechaza, y en producción sería un agujero.
- Defensa CSRF: `SameSite=Strict` con `Path` acotado a `/api/auth/web` es lo que fija
  ADR-0014 §5. El double-submit entra solo si aparece un flujo cross-site legítimo.
- `StrictThrottle` en los tres, como ya lo tienen `login` y `refresh` — aceptan
  credenciales sin autenticación previa.
- **`Secure` sale de una variable de entorno con default `true`.** No de una
  condición en el código ni de `NODE_ENV`. El desarrollo local la apaga
  explícitamente en su `.env`; olvidarse de configurarla en cualquier otro lado
  produce la cookie segura, no la insegura. Va a `.env.example` con su advertencia.

## UI

```
┌─ Snapline ────────────────────────── [ES/EN] [◐] [WF] ┐
├────────────┬──────────────────────────────────────────┤
│ Proyectos  │  Proyectos                               │
│ Clientes   │  ┌────────────────────────────────────┐  │
│ Cuadrillas │  │ (lista sintética, scrolleable)     │  │
│ Horas      │  │  conserva la posición al volver    │  │
│ Catálogo   │  └────────────────────────────────────┘  │
│ Facturación│                                          │
│ Reportes   │                                          │
│ Publicar   │                                          │
└────────────┴──────────────────────────────────────────┘
```

Cada eje cuelga de un permiso que el API ya calcula:

| Eje | Permiso | Quién lo ve |
|---|---|---|
| Proyectos | `projects.read` | todos |
| Clientes | `customers.read` | OWNER · ADMIN · ACCOUNTANT |
| Cuadrillas | `crews.read` | OWNER · ADMIN · FOREMAN |
| Horas | `time.read` | todos |
| Catálogo | `catalog.read` | OWNER · ADMIN · ACCOUNTANT |
| Facturación | `billing.read` | OWNER · ADMIN · ACCOUNTANT |
| Reportes | `reports.read` | OWNER · ADMIN · ACCOUNTANT |
| Publicar | `projects.publish` | OWNER · ADMIN |

**El panel no bloquea por rol.** Quien tenga membresía activa entra y ve lo que sus
permisos habilitan: un `WORKER` que abra el panel encuentra Proyectos y Horas y nada
más. Cerrarle la puerta sería inventar una regla que el dominio no tiene (regla 1), y
el guard del API sigue autorizando cada llamada de todas formas — el permiso solo
decide qué se dibuja.

## Criterios de aceptación

- [x] Entrar con teléfono y entrar con email funcionan igual, sin que el formulario
      pregunte cuál es.
- [x] `localStorage` y `sessionStorage` están vacíos después de un login exitoso.
- [x] La respuesta de `/auth/web/login` **no contiene** `refreshToken`, y su DTO en
      `openapi.json` tampoco declara el campo.
- [x] La cookie es `HttpOnly`, `SameSite=Strict`, con `Path=/api/auth/web` y
      `Max-Age=2592000`. **El `Path` lleva el prefijo global del API**: el spec
      decía `/auth/web`, y con ese valor la cookie no viajaría a ninguna de las
      tres rutas, que cuelgan de `/api`.
- [x] Recargar la página mantiene la sesión sin volver a pedir credenciales, y
      cerrar el navegador y volver a abrirlo también.
- [x] Con el access token vencido, la primera llamada dispara el refresh y **se
      reintenta sola**, sin que el usuario vea un error.
- [x] Cerrar sesión sube `membership.token_version`, y **reusar la cookie vieja
      responde 401 `TOKEN_INVALID`** aunque su firma siga siendo válida. Se verifica
      guardando el valor de la cookie antes del logout y reenviándolo después.
- [x] `token_version` no se acepta del cliente por ninguna vía: no está en ningún
      DTO de entrada, y mandarlo en el body de login o refresh no lo cambia.
- [x] `POST /auth/web/logout` es idempotente: sin cookie, o llamado dos veces,
      responde 204.
- [x] La migración pone `token_version` en `NOT NULL DEFAULT 0`, y las membresías
      que ya existen quedan en 0.
- [x] **Un refresh token emitido antes del deploy sigue funcionando después.** Es el
      criterio que el `?? 0` hace posible: con igualdad estricta se caen todas las
      sesiones vivas, y el test tiene que usar un token sin el claim `tv`.
- [x] `auth_memberships_for_user()` devuelve `token_version`, extendida en la misma
      migración que agrega la columna.
- [x] `token_version` va con `select: false` y `@ApiHideProperty()` en la entity, y
      no aparece en `openapi.json` ni como propiedad de ningún schema.
- [x] Un refresh que falla por red muestra falta de conexión, **no** la pantalla de
      login. Un login manual sin red muestra lo mismo, no un error de credenciales.
- [x] `Secure` sale de una variable de entorno con default `true`, está en
      `.env.example`, y el panel corre en `http://localhost:4200` con la sesión
      funcionando de punta a punta.
- [x] El origen permitido por CORS sale de su propia variable de entorno, también en
      `.env.example`. **No hay `*` en ningún lado**: con `credentials: true` el
      navegador lo rechaza, y un origen distinto del configurado falla el preflight.
- [x] La navegación se dibuja desde `membership.permissions[]`. Un rol sin
      `billing.read` no ve Facturación, y la tabla de roles no está duplicada en
      Angular.
- [x] Cambiar de eje y volver conserva la posición de scroll del anterior.
- [x] El panel arranca en `user.locale`, y cambiarlo desde la interfaz lo persiste
      con `PATCH /auth/me/locale` y sobrevive a la recarga.
- [x] **Cero cadenas quemadas** (regla 24): labels, botones, placeholders, errores y
      estados vacíos pasan por Transloco, en `en` y en `es`.
- [x] `openapi.json` regenerado con los tres endpoints nuevos, y
      `packages/contracts` al día (regla 8).
- [x] Tests del API para los tres endpoints, incluidos los que verifican que el
      refresh no sale en el body y que la cookie es `httpOnly`.

## Riesgos / consideraciones

- **Dos caminos de autenticación en el mismo API.** Bearer para el móvil, cookie
  para web. Es el costo aceptado en ADR-0014 y hay que sostenerlo: un endpoint nuevo
  tiene que funcionar con los dos. La mitigación es que el guard resuelva el token de
  las dos fuentes en un único lugar.
- **CSRF es la contrapartida de la cookie.** Se cambia una clase de riesgo por otra;
  la diferencia es que esta se mitiga con configuración.
- **La excepción de `Secure` para desarrollo no puede filtrarse a producción.** De
  ahí que el default de la variable sea `true` y no al revés.
- **30 días de cookie en una máquina compartida.** Se eligió coherencia con la
  sesión del móvil. Si el panel termina abriéndose en una computadora de oficina
  compartida, la conversación que sigue es un "mantener sesión iniciada" opcional,
  no acortar el plazo para todos.
- **`token_version` toca al móvil sin que el móvil lo haya pedido.** El campo vive
  en la membresía y el claim lo emite `issue()`, que es compartido: los tokens del
  teléfono empiezan a llevarlo el mismo día. Mientras nadie use el logout del panel
  no cambia nada para él, pero **el primer logout de William en la computadora tira
  su sesión del teléfono**. Es el comportamiento correcto del mecanismo y aun así se
  va a sentir como un bug. Es la decisión que `domain-guardian` tiene que mirar antes
  de la migración; la salida, si no se acepta, es una tabla de sesiones por
  dispositivo y otro alcance.
- **La migración corre sobre datos existentes.** `NOT NULL DEFAULT 0` deja todas las
  membresías en cero y ninguna sesión viva se cae al desplegar. Un default distinto,
  o un `NOT NULL` sin default, expulsa a todo el mundo de una vez.

## ADRs relacionados

- [[../../../adr/0002-superficies-flutter-angular/README|ADR-0002]] — Angular para el admin
- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — el contrato y sus clientes
- [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] — los errores que el interceptor traduce
- [[../../../adr/0014-sesion-web-en-cookie/README|ADR-0014]] — la sesión en cookie `httpOnly` y su camino propio en el API

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-30 | borrador | Creado. Sale de partir el spec original de cimientos en dos, tras la revisión de `spec-reviewer` |
| 2026-08-31 | en-implementacion | Arranca la implementación en `feature/web-0008-sesion`. Los iconos del shell se resuelven con `MatIconRegistry` y SVG propios, que cierra [[../../../tech-debt/0009-el-panel-no-tiene-iconos\|DEBT-0009]] |
| 2026-08-31 | en-implementacion | Los tres endpoints, la migración y el shell. 34 tests nuevos: 11 e2e de sesión contra Postgres, 7 unitarios del contador, 7 de la cookie y 23 del panel. Dos correcciones al spec, las dos por lo mismo —el `Path` de la cookie y el `Path` del contrato omitían el prefijo global `/api`, y con `/auth/web` la cookie no viaja a ninguna de las tres rutas—. La función `auth_memberships_for_user()` se recrea con `DROP` + `CREATE` y no con `CREATE OR REPLACE`: Postgres no deja cambiar el tipo de retorno. Los iconos entraron con `MatIconRegistry` y SVG propios, cerrando [[../../../tech-debt/0009-el-panel-no-tiene-iconos\|DEBT-0009]] |

| 2026-08-31 | en-implementacion | **Pasada de diseño y de copy sobre lo implementado, y el alcance del contenido creció a conciencia.** Probándolo en el navegador salieron tres cosas que los tests no ven: la cadena de alto y ancho se cortaba en el host de cada componente ruteado —`flex: 1` estaba en el `<section>` de adentro y nunca en el `:host`, así que la pantalla medía 383px de ancho y 4469 de alto y el scroll se lo quedaba Material—, el shell no tenía jerarquía ni forma de plegarse, y el panel no usaba el lockup de marca que `brand/logo-mark.svg` y `apps/mobile/lib/core/brand/` ya definían. El copy se reescribió contra la voz que el móvil ya tiene —usted, no vos— reusando sus cadenas de login en vez de inventar unas paralelas. Entró `sl-page` con encabezado propio y los tres estados de red, `sl-chip`, el parcial de tabla, y pipes de moneda, fecha, horas y porcentaje por Intl con el idioma activo. Los reportes recibieron sus DTO: devolvían `{"type":"object"}` sin propiedades, que es el defecto que la regla 8 describe, y sus agregados llegaban como texto. El seed de desarrollo creció a 6 obras, 4 clientes, 9 registros de horas, 6 ítems, un estimado, dos facturas y un pago. Dos huecos del contrato quedaron registrados en [[../../../tech-debt/0010-listados-sin-la-persona\|DEBT-0010]] |
| 2026-08-31 | en-implementacion | `code-reviewer` pasado: **listo para PR, sin hallazgos GRAVE**. Un MEDIO propio, corregido: el scrim del cajón angosto tenía `rgb(0 0 0 / 40%)` literal, contra la regla 22, y ahora consume `--mat-sys-scrim` mezclado con `color-mix`. Un MENOR preexistente en `main` que no toca este cambio: `test/invariantes.e2e-spec.ts` tiene una variable sin usar, y el script `lint` del API corre solo sobre `src/**`, así que la carpeta `test/` no la cubre |
| 2026-08-31 | en-implementacion | Los dos arrastres de `main`, arreglados acá por decisión del dueño en vez de en un `fix/` aparte. **La causa de los dos era la misma**: `pay_rate_cents_snapshot` pasó a `select: false` en `6573a6d` y dos aserciones de `invariantes.e2e-spec.ts` seguían leyéndolo de la respuesta, así que comparaban contra `undefined`; ahora comprueban el invariante en la base, que es donde vive, y de paso verifican que la tarifa **no** viaje al cliente. El script `lint` del API corría `eslint "src/**/*.ts"`, así que `test/` no lo cubría nadie y por ahí pasó la variable sin usar: pasa a `eslint .`, igual que `apps/web`, y la config ya ignora `dist`. La suite e2e completa queda en 53 verdes, estable en tres corridas |
| 2026-08-31 | en-implementacion | **Los cinco criterios que pedían navegador, verificados a mano por @jaca** contra el API y el panel corriendo: recargar y reabrir sin volver a pedir credenciales, el idioma que sobrevive a la recarga, el scroll de cada eje, el almacenamiento sin nada de sesión, y el recorrido completo en `http://localhost:4200`. Todos los criterios en `[x]`; queda el PR |
