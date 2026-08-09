---
id: SPEC-0001
title: "Login en la app móvil"
aliases:
  - "SPEC-0001: Login en la app móvil"
type: spec
platform: mobile
status: en implementación
goal: "El trabajador entra con su teléfono o su email indistintamente, la app queda en el idioma de su usuario, y al reabrirla sigue adentro sin escribir nada."
apps:
  - mobile
depends_on: []
domain:
  - usuario-y-membresia
  - empresa
frente: plataforma
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0001: Login en la app móvil

> **Meta**
> - Apps afectadas: `mobile`
> - Depende de: —
> - Frente: `plataforma`
>
> _Estado, goal, tags y resto de metadata viven en el frontmatter arriba._

---

## Problema

El trabajador de William abre la app parado en una obra, con guantes y con una mano
ocupada. Es la primera pantalla que ve del producto y la única que no puede
resolverse sin red, así que es donde más fácil se pierde a un usuario.

Dos cosas la complican, y las dos salen del dominio:

- **Muchos trabajadores no tienen email.** [[../../../domain/usuario-y-membresia|usuario-y-membresia]]
  marca `email` y `phone` como opcionales con la regla de que al menos uno exista.
  Un formulario que pida "email" deja afuera a parte de la cuadrilla.
- **El idioma es del usuario, no de la empresa.** William administra en inglés y es
  probable que sus trabajadores usen la app en español, dentro de la misma cuenta.

Y una del producto: *"si William necesita un tutorial, ya perdimos"*. Iniciar sesión
una sola vez y no volver a pensar en eso es parte de esa promesa.

## Alcance

### Entra

- Un **único campo de identificación** que acepta teléfono o email, sin que el
  usuario elija cuál está escribiendo.
- Campo de contraseña con alternar visibilidad.
- Sesión persistida en almacenamiento seguro del sistema, de modo que reabrir la
  app no pida credenciales.
- Renovación silenciosa del access token cuando vence, usando el refresh token.
- Aplicar `user.locale` de la respuesta al idioma de la app, y persistirlo.
- Estados de error distinguibles: credenciales inválidas, sin conexión, y servidor
  caído.
- Cierre de sesión, que borra tokens y caché local.

### No entra

- **Registro de usuario.** Las cuentas las crea el admin invitando; el dominio
  define `status: invitado` para eso. No hay auto-registro.
- **Recuperar contraseña.** No hay endpoint todavía y hace falta decidir si va por
  SMS o por email, lo que depende de qué tenga cargado cada trabajador.
- **Selector de empresa.** El API ya devuelve `memberships[]` con todas las activas,
  así que el dato está; lo que no existe es un endpoint para cambiar de membresía
  sin volver a loguearse. Cuando aparezca la primera persona que trabaja para dos
  contratistas, eso es un spec propio. La app guarda la lista igual, para no tener
  que tocar el almacenamiento cuando llegue.
- **Biometría.** La sesión dura 30 días; agregar huella antes de tener queja real
  es resolver un problema que nadie reportó.
- Login con Google o Apple.

## Modelo de dominio afectado

- [[../../../domain/usuario-y-membresia|usuario-y-membresia]]
- [[../../../domain/empresa|empresa]]

No introduce agregados nuevos.

## Comportamiento sin señal

Es la única acción de la app que **no puede completarse sin red**: el token lo
emite el servidor y no hay forma de validar una contraseña contra nada local sin
guardar material sensible en el dispositivo.

Lo que sí se define es que la falta de red no se confunda con un error de
credenciales:

| Situación | Comportamiento |
|---|---|
| Sesión válida guardada, sin red | **Entra igual.** La app abre con la sesión cacheada y trabaja offline. |
| Access token vencido, sin red | **Entra igual.** El refresh se reintenta cuando vuelva la red; el token vencido no expulsa a nadie de la app. |
| Refresh token vencido (30 días), sin red | **Sigue capturando.** Ver abajo. |
| Sin sesión previa, sin red | Pantalla de login con mensaje explícito de falta de conexión. El botón queda disponible para reintentar. |

**Un token vencido nunca borra la sesión ni los datos locales.** Un trabajador que
pasó dos semanas en obras sin cobertura tiene que poder seguir marcando; sus
registros se sincronizan cuando la sesión se renueve.

### Más de 30 días sin cobertura

Cuando vence también el refresh y no hay red para renovarlo, **la app no expulsa al
usuario ni le impide trabajar**. Sigue permitiendo marcar entrada y salida y tomar
fotos: los registros nacen con su UUIDv7 en el dispositivo (regla 18) y quedan en
`PENDING` hasta que haya red.

Al recuperar conexión la app pide la contraseña, y recién con la sesión renovada
sincroniza todo lo acumulado.

La alternativa —bloquear hasta reautenticar— contradice la regla 9: un trabajador
que no puede fichar deja de usar la app el primer día. Lo que se pierde sin sesión
válida es **sincronizar**, no **capturar**.

### Token vencido a mitad de sesión

La renovación silenciosa no ocurre solo al abrir la app. Cualquier respuesta `401`
de cualquier endpoint dispara un intento de refresh en el interceptor de Dio, y la
petición original se reintenta una vez con el token nuevo.

Si el refresh también falla, se aplica la tabla de arriba según haya red o no. En
ningún caso un `401` interrumpe al usuario con una pantalla de login encima de lo
que estaba haciendo.

## Flujo de usuario

```
abre la app
     │
     ├── hay sesión guardada ──▶ entra directo (renueva token en segundo plano)
     │
     └── no hay sesión
              ▼
        pantalla de login
              │
         escribe identificador + contraseña
              ▼
        POST /auth/login
              │
              ├── 200 ──▶ guarda tokens ──▶ aplica user.locale ──▶ entra
              │
              ├── 401 ──▶ "Revisá tu usuario o contraseña"
              │
              └── sin red ──▶ "No hay conexión. Probá de nuevo."
```

El teclado se adapta a lo que se está escribiendo: si el identificador empieza con
un dígito, teclado numérico; si no, teclado de texto con autocorrección apagada.

## Contrato de API

Los endpoints existen y están documentados en `openapi.json`. El cliente Dart se
genera de ahí y **no se escribe a mano**.

```http
POST /auth/login
{ "identifier": "301-555-0142", "password": "..." }
```

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "expiresInSeconds": 3600,
  "user":        { "id": "...", "name": "...", "locale": "es",
                   "email": "...", "phone": "301-555-0142" },
  "membership":  { "id": "...", "companyId": "...", "companyName": "...", "role": "WORKER" },
  "memberships": [ { "id": "...", "companyId": "...", "companyName": "...", "role": "WORKER" } ]
}
```

```http
POST /auth/refresh
{ "refreshToken": "..." }
```

Respuesta idéntica a la de login.

Tres cosas del contrato que condicionan la implementación:

- **`identifier` resuelve contra `email` o `phone` en el servidor**, que además
  normaliza el teléfono a E.164 antes de comparar. La app manda el texto tal cual
  se escribió y **no intenta adivinar de qué tipo es**.
- **`expiresInSeconds` lo dice el servidor.** La vigencia del access token no se
  codifica en la app: si el API la cambia, el móvil se entera solo.
- **`memberships[]` trae todas las activas** y `membership` es a la que quedó
  scopeado el token. Este spec guarda las dos, pero solo usa `membership`; ver
  abajo por qué el selector queda fuera.

## UI

Una sola pantalla, sin scroll en un teléfono chico.

```
┌─────────────────────────┐
│                         │
│      ╲                  │   logo Snapline, atenuado
│       ╲  Snapline       │   (marca presente, no protagonista)
│                         │
│  Teléfono o correo      │
│  ┌───────────────────┐  │
│  │                   │  │   un solo campo, 56dp
│  └───────────────────┘  │
│                         │
│  Contraseña             │
│  ┌───────────────────┐  │
│  │              👁    │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │     ENTRAR        │  │   64dp, ancho completo
│  └───────────────────┘  │
│                         │
│  △ No hay conexión      │   chip de estado, solo si aplica
│                         │
└─────────────────────────┘
```

- El botón es la única cosa naranja saturada de la pantalla, según el ADR-0009.
- Los errores aparecen como chip de estado con icono, nunca solo con color.
- El label del botón entra en una línea en español ("Entrar" / "Sign in").
- Mientras el request está en vuelo el botón muestra progreso y queda deshabilitado,
  para que un doble toque con guante no dispare dos logins.

## Criterios de aceptación

Verificados con `flutter test` o en simulador:

- [x] Cerrar la app y reabrirla entra directo, sin pedir credenciales.
- [x] Al reabrir sin red, la app conserva el idioma del último login: sale de la
      sesión guardada y no de una llamada al servidor.
- [x] Un usuario con `locale: en` ve la app en inglés y uno con `es` en español.
- [x] Sin conexión, el mensaje dice que falta conexión y no "credenciales
      inválidas" — cubierto en `test/api_failure_test.dart` para las cuatro
      variantes de fallo de red.
- [x] Una contraseña incorrecta se clasifica como credenciales y no como red.
- [x] Los tokens no aparecen en el texto de la sesión, que es lo que termina en
      logs y reportes de error.
- [x] Con los campos vacíos no se llama al API.
- [x] La pantalla se ve correcta en claro y en oscuro. Contraste AA verificado
      sobre `design-tokens.json` para los 34 pares.
- [x] No hay ninguna cadena de texto quemada: todo pasa por i18n en `en` y `es`.

Verificados contra el API real, en `integration_test/login_test.dart`:

- [x] Con un usuario que tiene solo `phone`, se entra escribiendo el teléfono.
- [x] El mismo teléfono entra escrito sin formato: el servidor normaliza a E.164.
- [x] Con un usuario que tiene solo `email`, se entra escribiendo el email.
- [x] Cerrar sesión borra la sesión guardada y vuelve al login.

Verificados en `test/auth_interceptor_test.dart`:

- [x] Con el access token vencido y red disponible, la app renueva sin que el
      usuario note nada.
- [x] Un `401` a mitad de sesión dispara el refresh y reintenta la petición una
      vez, sin mostrarle al usuario una pantalla de login.
- [x] El reintento ocurre **una sola vez**: un `401` después de renovar no entra
      en bucle.
- [x] Si el refresh falla, la sesión no se borra ni se renueva.
- [x] Varias peticiones en paralelo con el token vencido comparten un solo
      refresh, en vez de rotar el token una vez por petición.

Bloqueado por otra feature:

- [ ] Con el refresh token vencido y sin red, se puede marcar entrada y la marca
      queda `PENDING`; al reautenticar, sincroniza. **La sesión ya no se borra al
      fallar el refresh, que es la mitad que corresponde a este spec; la otra
      mitad necesita la captura offline, que todavía no existe.**

## Riesgos / consideraciones

**El API elige la membresía sin criterio.** `apps/api/src/auth/auth.service.ts:13`
hace `const [membership] = await this.membershipsForUser(user.id)`: toma la primera
fila, y la consulta no lleva `ORDER BY`. El dominio documenta explícitamente el caso
de una persona que trabaja para dos contratistas, así que hoy esa persona entraría a
una empresa arbitraria y potencialmente distinta en cada login.

No bloquea este spec —William es un solo contratista y el móvil no puede arreglarlo
solo— pero se resuelve en `apps/api` antes de que exista el segundo cliente.
Registrado en [[../../../tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002]],
severidad alta: el modo de fallo es silencioso y termina atribuyendo registros de
tiempo a la empresa equivocada, sobre un agregado que por la regla 12 no se
sobrescribe.

**El refresh token de 30 días vive en el dispositivo.** Dónde y por qué lo decide
el [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]], no este spec:
Keychain y Keystore vía `flutter_secure_storage`, nunca `SharedPreferences` ni una
tabla de Drift.

**Un teléfono se escribe de muchas formas.** `301-555-0142`, `3015550142` y
`+13015550142` son el mismo número para una persona y tres strings distintos para
la consulta del servidor. Registrado en
[[../../../tech-debt/0003-telefono-sin-normalizar|DEBT-0003]]; normalizar es
trabajo de `apps/api`.

## ADRs relacionados

- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]] — Riverpod, Drift y
  cliente generado
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — la regla del
  naranja y el tamaño de la acción primaria

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | borrador | Creado |
| 2026-08-08 | review | Revisado con `spec-reviewer`. Dos bloqueantes resueltos: el contrato pasa a prerequisito declarado, y el almacenamiento seguro se movió al ADR-0008. Sumados el caso de más de 30 días sin cobertura y el 401 a mitad de sesión. |
| 2026-08-08 | en implementación | Aprobado. El prerequisito del contrato quedó resuelto en `apps/api`: `AuthResultDto` documentado y `authLogin` ya devuelve tipo. Contrato actualizado con `expiresInSeconds` y `memberships[]`. |
| 2026-08-08 | en implementación | Implementado y verificado: 27 tests unitarios y 5 de integración contra el API real. Queda un solo criterio abierto, y depende de la captura offline. |
