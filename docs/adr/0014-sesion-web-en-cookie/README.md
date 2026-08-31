---
id: ADR-0014
title: "La sesión del panel vive en cookie httpOnly, con su propio camino en el API"
aliases:
  - "ADR-0014: La sesión del panel vive en cookie httpOnly, con su propio camino en el API"
type: adr
status: propuesto
supersedes: null
superseded_by: null
related_specs:
  - SPEC-0008
created: 2026-08-30
updated: 2026-08-30
deciders:
  - jaca
tags:
  - adr
  - adr/propuesto
  - seguridad
---

# ADR-0014: La sesión del panel vive en cookie httpOnly, con su propio camino en el API

> **Meta**
> - Deciders: @jaca
>
> _Estado y fecha viven en el frontmatter arriba — no duplicar aquí._

## Contexto

El API emite `accessToken` y `refreshToken` en el cuerpo de la respuesta. Ese diseño
se hizo para el móvil, que los guarda en el almacenamiento seguro del sistema
operativo — Keychain en iOS, Keystore en Android. Ahí el token está protegido por el
SO y otra app no lo lee.

**El navegador no tiene equivalente.** Todo lo que JavaScript puede leer, un XSS
puede leer: `localStorage`, `sessionStorage` y cualquier variable alcanzable desde
el bundle. Angular escapa y sanitiza por defecto, lo que hace el XSS improbable, no
imposible — y la consecuencia de que ocurra no es proporcional a esa probabilidad.

Qué hay del otro lado de un token robado del panel: direcciones de las casas de los
clientes, sus teléfonos, facturas, y fotos que llevan GPS adentro. Con el refresh
token, un mes de acceso al tenant completo.

La restricción que hace que se decida ahora y no después es al revés de lo habitual:
**no hay una sola pantalla escrita ni un usuario real**. Es la ventana más barata
que va a existir. Es el mismo razonamiento de la regla 6 con `company_id` —
*"barato hoy, carísimo después con datos reales adentro"*.

## Decisión

### 1. El access token en memoria, el refresh en cookie `httpOnly`

```
login  ──▶  accessToken   ──▶  variable en memoria, muere con la pestaña
       └─▶  refreshToken  ──▶  Set-Cookie: HttpOnly; Secure; SameSite=Strict
                                            Path=/auth/web; Max-Age=2592000
```

Al recargar, la memoria está vacía y el panel pide un refresh; la cookie viaja sola
y la sesión vuelve sin que el usuario escriba nada.

**`Max-Age` calza con la vida del JWT: 30 días, los mismos que el móvil.** Sin ese
atributo sería una cookie de sesión y moriría al cerrar el navegador — sobreviviría
al F5 pero no a terminar la jornada, que es una decisión distinta a la que se tomó.
Se eligió coherencia con la sesión del teléfono; si el panel termina abriéndose en
una computadora de oficina compartida, lo que sigue es un "mantener sesión iniciada"
opcional, no acortarle el plazo a todos.

### 2. El refresh **nunca** aparece en el cuerpo de una respuesta web

Es el punto entero de la decisión. Si el token viaja en el body, un XSS lo lee de la
respuesta y la cookie no protegió nada.

### 3. El panel tiene su propio camino en el API

`POST /auth/web/login`, `POST /auth/web/refresh` y `POST /auth/web/logout`, los tres
delegando en el mismo `AuthService`. **El contrato del móvil no se toca.**

### 3b. El logout invalida con `membership.token_version`

Borrar la cookie del navegador no alcanza. El refresh es un **JWT autofirmado y sin
estado** —`refresh()` solo hace `jwt.verifyAsync()`— así que una vez emitido vale 30
días y no hay dónde anotar que dejó de servir: no existe tabla de sesiones, ni `jti`,
ni denylist.

Un entero en la membresía, que viaja en el claim y se compara al refrescar:

```
logout     ─▶ UPDATE membership SET token_version = token_version + 1
refresh()  ─▶ (claim.tv ?? 0) == membership.token_version ?  no ─▶ 401 TOKEN_INVALID
```

Lo escribe el servidor y nunca se acepta del cliente.

**El claim ausente vale 0.** Los tokens ya emitidos no lo llevan —`AccessTokenPayload`
no lo tiene— y con igualdad estricta `undefined === 0` es `false`: el deploy
expulsaría a toda sesión viva. Es un detalle de implementación que se documenta acá
porque equivocarlo produce una caída silenciosa y masiva el primer día.

**Invalida por membresía, no por dispositivo.** Cerrar sesión en el panel también
tira la sesión del teléfono de esa persona en esa empresa. Se elige igual porque la
alternativa —una tabla de sesiones con un registro por dispositivo— es un agregado
nuevo, y prometer un logout que no invalida nada era la opción peor. Registrado en
[[../../tech-debt/0008-logout-invalida-por-membresia|DEBT-0008]], con su trigger.

En `membership` y no en `app_user` a propósito: ahí, cerrar sesión en una empresa
invalidaría también la sesión de esa misma persona en otra.

### 4. CORS con origen explícito, nunca `*`

Con `credentials: true` el navegador rechaza el comodín, y en producción sería un
agujero. Origen de desarrollo `http://localhost:4200`; en producción, el dominio
real.

### 5. CSRF: `SameSite=Strict` primero, double-submit si hace falta

La cookie se manda sola, y eso es exactamente lo que habilita el CSRF. `SameSite=Strict`
con `Path` acotado a `/auth/web` cubre el caso común. Si aparece un flujo cross-site
legítimo que obligue a relajarlo, entra un token double-submit — y esa relajación
se decide explícitamente, no como efecto colateral de otra cosa.

## Alternativas consideradas

### Alternativa A — `localStorage`, detrás de un servicio intercambiable

Cero cambios al API, el spec queda en una sola app y la primera pantalla llega antes.
Es lo que hace la mayoría de las SPA.

**Por qué no:** un XSS se lleva un refresh token de 30 días. La abstracción
intercambiable suena a mitigación pero no lo es: no reduce el riesgo, solo abarata
el cambio posterior. Y el momento de hacer el cambio nunca es más barato que hoy,
que no hay ni una pantalla.

### Alternativa B — Todo en memoria, sin persistir nada

Máximo aislamiento y cero cambios al API.

**Por qué no:** recargar la página pide login de nuevo, y abrir una pestaña nueva
también. Choca de frente con la primera de las dos apuestas del producto: *"si
William necesita un tutorial, ya perdimos"*. Un panel que expulsa a cada F5 se
abandona.

### Alternativa C — Un flag sobre los endpoints existentes

`POST /auth/login` recibe algo que le dice "soy web" y responde con cookie en vez de
body. Un solo camino, sin duplicar rutas.

**Por qué no:** obliga a volver `refreshToken` opcional en `AuthResultDto`, que el
móvil ya consume y sobre el que hay trabajo en vuelo — el modelo Dart pasaría a
nullable sin que ninguna pantalla lo necesite. **Un campo que a veces está y a veces
no es peor contrato que dos rutas explícitas**, y en `openapi.json` se documenta
como una respuesta ambigua en vez de dos claras.

## Consecuencias

### Positivas

- Un XSS en el panel deja de ser catastrófico: no hay token que robar del storage, y
  la cookie es invisible para JavaScript.
- El contrato del móvil queda intacto, y con él los modelos Dart generados.
- `openapi.json` documenta los dos caminos sin ambigüedad, cada uno con su forma.
- El logout invalida del lado del servidor, no solo borrando algo del cliente — y el
  mecanismo queda disponible para un "cerrar todas las sesiones" cuando se pida.

### Negativas / Costos

- **Dos caminos de autenticación en el mismo API**, y hay que sostenerlos: un
  endpoint nuevo tiene que funcionar con bearer y con cookie.
- **CSRF entra como preocupación nueva.** Se cambia una clase de riesgo por otra;
  la diferencia es que esta se mitiga con configuración y la de XSS con suerte.
- `Secure` no viaja por `http://localhost`. El desarrollo local necesita su
  resolución, y esa resolución no puede filtrarse a producción.
- **Una columna nueva en `membership` y una consulta más en cada refresh.** El precio
  de que el logout signifique algo: sin estado, un JWT autofirmado no se revoca.
- **El logout del panel expulsa el teléfono de la misma persona.** La invalidación es
  por membresía; separarla por dispositivo exige una tabla de sesiones que no existe.

### Riesgos

- **Que un endpoint nuevo ande con bearer y no con cookie, o al revés**, y el bug
  aparezca solo en una superficie. Mitigación: el guard resuelve el token de las dos
  fuentes en un único lugar; ningún controller decide de dónde sale.
- **Que la excepción de `Secure` para localhost llegue a producción.** Mitigación:
  que dependa de la configuración de entorno y no de una condición en el código.

### Qué lo revierte

Que aparezca un consumidor web legítimo que no pueda usar cookies —una extensión, un
cliente de terceros, un dominio que no comparte sitio. Ahí se evalúa un esquema de
tokens de corta vida con rotación, y este ADR se supersede.

## Impacto en el modelo

**Una columna nueva: `membership.token_version`** (entero, `NOT NULL DEFAULT 0`).

El resto de la decisión es sobre dónde viaja un token que ya existía, y eso no toca
el modelo. Pero la decisión 3b sí lo toca, y no había forma de cumplirla sin
hacerlo: sin estado en algún lado, un JWT autofirmado no se puede revocar.

- [[../../domain/usuario-y-membresia|usuario-y-membresia]] — la ficha ya lleva el
  campo y el invariante de que lo escribe solo el servidor
- [[../../specs/web/0008-sesion-y-shell/README|SPEC-0008: Sesión y shell del panel]]

> Por la regla 28, la migración pasa por `domain-guardian` antes de escribirse. El
> punto a mirar es el de la decisión 3b: que la invalidación sea por membresía y no
> por dispositivo.

## Referencias

- [[../0011-envelope-de-errores/README|ADR-0011]] — los errores que el interceptor del panel traduce por su `code`
- [[../0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]] — el otro camino de acceso sin membresía, que es independiente de este
- Regla 7 del `CLAUDE.md` — default deny: esto cambia cómo llega el token, no quién autoriza
