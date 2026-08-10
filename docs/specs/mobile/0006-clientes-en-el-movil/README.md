---
id: SPEC-0006
title: "Clientes en el móvil"
aliases:
  - "SPEC-0006: Clientes en el móvil"
type: spec
platform: mobile
status: implementado
goal: "William encuentra un cliente por nombre o teléfono sin señal, ve sus propiedades y sus obras en una sola pantalla, y da de alta o corrige un cliente con su propiedad parado en la obra sin esperar cobertura."
apps:
  - mobile
  - api
depends_on:
  - "0003-arquitectura-de-navegacion"
  - "0004-capa-local-y-sincronizacion"
domain:
  - cliente
frente: administrativo
created: 2026-08-09
updated: 2026-08-09
tags:
  - spec
  - spec/implementado
  - mobile
---

# SPEC-0006: Clientes en el móvil

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0003-arquitectura-de-navegacion/README|SPEC-0003]],
>   [[../0004-capa-local-y-sincronizacion/README|SPEC-0004]]
> - Frente: `administrativo`

---

## Problema

El eje de Clientes es un placeholder. Y sin clientes en el dispositivo, el alta
de obra de [[../0005-proyectos-en-el-movil/README|SPEC-0005]] no tiene de dónde
elegir: este spec es su prerequisito de datos, no un frente paralelo.

El dominio dice que el cliente *"se crea desde el móvil —William registra un
cliente parado en la obra— con UUIDv7 local"*. Es el flujo principal del
prototipo, no un caso secundario.

## Alcance

### Entra

- **Lista de clientes** leída de local, con búsqueda por nombre, empresa o
  teléfono.
- **Detalle**: sus datos, sus propiedades y sus obras.
- **Alta de cliente**, con UUIDv7 local.
- **Alta de propiedad (`site`)** dentro del cliente — es de donde cuelga.
- **Los formularios mínimos de alta**, que [[../0005-proyectos-en-el-movil/README|SPEC-0005]]
  reutiliza dentro del alta de obra. Se definen acá una sola vez; si se copian
  allá, divergen.
- **Edición** de los campos editables del dominio.
- **`site.update` en `apps/api`**, que SPEC-0004 dejó nombrado sin criterio y sin
  implementar. Sin él, corregir una dirección no tiene camino ni online ni
  offline. Entra acá porque es este spec el que lo necesita.

### No entra

- **Otorgar el photo release.** Necesita el documento firmado adjunto, y el
  dominio dice explícitamente que **no se puede setear desde el móvil sin él**.
  Se muestra si está o no está; otorgarlo es otro spec, con la subida del papel.
- **Invitar al portal del cliente.** Es el frente `cliente` y ya tiene su spec en
  `docs/specs/web/`.
- **La geocerca.** `lat`, `lng` y `geofence_radius_m` son del sitio y los usa
  asistencia; ajustarlos desde el móvil entra con el frente `campo`.
- **Fusionar duplicados.** Va a hacer falta —ver riesgos— pero no ahora.
- **Editar la geocerca de una propiedad.** La dirección sí se corrige; `lat`,
  `lng` y el radio son de asistencia y entran con el frente `campo`.

## Modelo de dominio afectado

- [[../../../domain/cliente|cliente]] — se implementan `customer` y `site` tal
  como están en la ficha.

No se agrega nada al modelo.

## Las reglas del dominio que aplican

- **`photo_release_granted_at` es lo único que habilita `PUBLIC`**, y la
  restricción vive en la base de datos. El móvil **lo muestra, no lo decide**.
- **`photo_release_granted_at` no se setea desde el móvil sin documento
  firmado.** El campo es de solo lectura en esta pantalla.
- **Revocar el release despublica lo público asociado.** Como revocar no entra en
  este alcance, la pantalla tampoco ofrece revocarlo — ofrecerlo sin implementar
  la despublicación sería peor que no tenerlo.
- **La geocerca pertenece al sitio, no al proyecto.** El mismo cliente puede
  tener tres trabajos en la misma casa: la propiedad es una y se reutiliza.
- **Para invitar al portal hace falta `email` o `phone`.** El alta no los exige
  —el dominio los marca opcionales— pero la pantalla avisa que sin uno de los dos
  ese cliente no va a poder entrar al portal.

## Comportamiento sin señal

| Situación | Comportamiento |
|---|---|
| Buscar | Sobre local. Sin red no cambia nada. |
| Crear cliente | UUIDv7 local, `PENDING`, a la bandeja. Aparece al instante y **ya se puede usar para crear una obra**. |
| Crear propiedad | Igual, colgada del cliente aunque el cliente todavía no haya sincronizado. |
| Editar | Se aplica local y se encola. Última escritura gana. |

El caso que importa: **crear cliente, crear su propiedad y crear la obra, los
tres sin señal y en ese orden.** Las tres operaciones se encolan y el servidor
las aplica en orden de `occurredAt`, que es justamente lo que el endpoint de sync
ya garantiza. Si esto no funciona, el prototipo no sirve.

## UI

- Lista con búsqueda arriba, siempre visible: el caso real es buscar, no
  navegar.
- La acción primaria es **"＋ Nuevo cliente"**, único naranja sólido.
- El detalle agrupa en secciones —datos, propiedades, obras— con la misma forma
  que la pantalla de cuenta: encabezado de sección y fichas con borde.
- El estado del photo release se muestra con `StatusChip`: presente o ausente,
  con icono. Es lo que decide si esa obra se puede publicar, así que se ve de un
  vistazo.

## Criterios de aceptación

- [x] La lista sale de local: apagando la red, la búsqueda sigue funcionando.
- [x] Ninguna pantalla de este frente importa un cliente de `lib/api/`.
      *(`api_isolation_test.dart`, que SPEC-0004 declaraba y no existía.)*
- [x] Buscar encuentra por nombre, por empresa y por teléfono.
- [x] Crear un cliente sin señal lo deja usable de inmediato para crear una obra
      en el mismo estado sin señal. *(Queda con su id definitivo y ya se le puede
      colgar una propiedad; que el alta de obra lo ofrezca lo verifica SPEC-0005.)*
- [x] Cliente, propiedad y obra creados offline en ese orden llegan al servidor
      en ese orden y sin duplicarse.
- [x] El id del cliente creado en el móvil es el mismo que queda en el servidor.
- [x] `photo_release_granted_at` es de solo lectura: no hay forma de otorgarlo ni
      revocarlo desde esta pantalla.
- [x] Un cliente sin `email` ni `phone` se puede guardar, y la pantalla avisa que
      no va a poder entrar al portal.
- [x] Una propiedad nueva queda asociada a su cliente, y la consulta de sitios de
      ese cliente la devuelve. *(Que aparezca en el selector del alta de obra lo
      verifica SPEC-0005, que es dueño de esa pantalla.)*
- [x] El detalle de un cliente lista sus propiedades y sus obras, y dice qué pasa
      cuando todavía no tiene ninguna de las dos.
- [x] Corregir el nombre, el teléfono o la dirección de un cliente sin señal se ve
      al instante y llega al servidor sin duplicarse.
- [x] `site.update` existe en `SYNC_OPERATIONS` con su `PATCH` REST, valida su
      payload, declara `customers.write` y tiene su caso en `edge-cases/`.
- [x] Corregir la dirección de una propiedad existente funciona sin señal.
- [x] Claro y oscuro correctos, y un solo naranja sólido por pantalla.
- [x] Cero cadenas quemadas, en `en` y `es`.

## Riesgos / consideraciones

**Editar una propiedad no tenía endpoint.** `site.create` lo resolvió
[[../0004-capa-local-y-sincronizacion/README|SPEC-0004]], pero `site.update` quedó
nombrado allá sin criterio y sin implementar: al arrancar este spec no existía
`PATCH` de `site` ni por REST ni por la bandeja, solo `GET` y `POST` bajo
`/customers/:id/sites`. Pasa a Alcance de este spec, que es el que lo necesita.

**Los duplicados van a aparecer.** Sin señal no hay forma de avisar que ese
cliente ya existe en otro dispositivo, y "Martínez" se va a cargar dos veces. No
se resuelve acá, pero conviene que el alta muestre coincidencias por nombre y
teléfono **de lo que hay en local** antes de guardar: es barato y ataja la mitad
de los casos.

**`display_name` es "como lo llama William".** El dominio no obliga a nombre y
apellido, así que el alta puede pedir un solo campo y quedarse ahí. Pedir la
ficha completa parado en un techo es lo que hace que la gente no cargue nada.

**La dirección ya está en el contrato.** Quedó definida en
[[../../../domain/cliente|la ficha de cliente]] —`line1`, `line2`, `city`,
`state`, `postal_code`, `country`—, es la misma para `billing_address` y
`site.address`, y SPEC-0004 la declaró como `AddressDto` en `apps/api`. Este spec
la consume; no la vuelve a definir.

## ADRs relacionados

- [[../../../adr/0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]] — por
  qué `email` o `phone` importan aunque sean opcionales

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-09 | borrador | Creado. Es prerequisito de datos de SPEC-0005: sin clientes y sitios en local, el alta de obra no tiene de dónde elegir. Queda abierta la forma de `billing_address`, que hay que cerrar antes de implementar. |
| 2026-08-09 | borrador | Cerrada la forma de la dirección: seis campos, la misma para `billing_address` y `site.address`, documentada en la ficha de cliente y pendiente de declararse como DTO en el API. Los formularios mínimos de alta pasan a ser de este spec, para que SPEC-0005 los reutilice en vez de copiarlos. |
| 2026-08-09 | borrador | Revisado con `spec-reviewer`. Confirmó por su cuenta el mismo agujero que encontró el revisor de SPEC-0005 —no existe `site.create`, y tampoco ningún `PATCH` de `site`—, que pasó a prerequisito de SPEC-0004. El goal se amplió para cubrir detalle y edición, que estaban en Alcance sin nada contra qué medirlos, y el criterio del selector de sitio se reformuló sobre algo que este spec controla. |
| 2026-08-09 | review | Verificados los prerequisitos contra el código, no contra el changelog: `AddressDto` y `site.create` están; `site.update` **no**, quedó nombrado en SPEC-0004 sin criterio. Pasa a Alcance de este spec y `apps` suma `api`. |
| 2026-08-09 | aprobado | Aprobado el orden de trabajo: este spec va antes de SPEC-0005 porque es su prerequisito declarado, y sus formularios mínimos de cliente y propiedad son los que el alta de obra reutiliza. |
| 2026-08-09 | en-implementacion | Arranca la implementación. |
| 2026-08-10 | implementado | PR #4 mergeado con los quince criterios en `[x]`. Revisado con `code-reviewer`: encontró que el desempate de la bandeja avanzaba en milisegundos cuando la columna guarda segundos —916ms medidos en el camino más común— y lo corrigió el mismo PR. Encontró además un **GRAVE preexistente en `main`**: el pull de `/sync` baja la cartera completa de clientes a un `WORKER` sin `customers.read`. No es regresión de este spec y va por su propia rama. |
| 2026-08-10 | en-implementacion | **Los tres criterios que faltaban, verificados contra el API corriendo.** `integration_test/customers_test.dart` pasa en simulador, y comprobado por fuera del test consultando el servidor: la propiedad quedó colgada de su cliente, la corrección de dirección se aplicó encima —412 Ellsworth Dr, no una segunda fila—, y los ids son los UUIDv7 que generó el teléfono. Todos los criterios en `[x]`; queda el PR. |
| 2026-08-10 | en-implementacion | Pasada de interfaz sobre lo implementado. El teléfono pide su país —`phone_form_field`, datos de libphonenumber en Dart puro, valida sin señal— y guarda E.164, que cierra desde el cliente la mitad del alta que [[../../../tech-debt/0003-telefono-sin-normalizar\|DEBT-0003]] dejó abierta. El país de la dirección se elige de lista en vez de teclearse. Lo obligatorio se dice en el label con palabras. El aviso del portal trae ayuda: `showHelpSheet` queda como componente reutilizable. Y tres arreglos de forma: el pie de los formularios respeta el área segura de abajo, los campos bajaron de 72 a 56 de alto, y los 64dp de ADR-0009 pasaron de ser la altura de todo botón sólido a pedirse solo en la acción de campo. |
| 2026-08-09 | en-implementacion | Lista, ficha, alta y corrección de cliente y propiedad, con `site.update` y su `PATCH` en el API. 48 tests nuevos. Un bug de la bandeja apareció escribiendo el caso crítico del spec: **el servidor ordena el lote por `occurredAt` y crear un cliente con su propiedad en el mismo toque las empataba al milisegundo**, así que la propiedad podía aplicarse antes que su cliente. `enqueue` corre el empate un milisegundo. Faltan los tres criterios que solo se cierran corriendo `integration_test/customers_test.dart` contra el API. |
