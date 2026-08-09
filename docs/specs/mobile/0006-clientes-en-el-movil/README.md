---
id: SPEC-0006
title: "Clientes en el móvil"
aliases:
  - "SPEC-0006: Clientes en el móvil"
type: spec
platform: mobile
status: borrador
goal: "William encuentra un cliente por nombre o teléfono sin señal, y da de alta uno con su propiedad parado en la obra sin esperar cobertura."
apps:
  - mobile
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
  - spec/borrador
  - mobile
---

# SPEC-0006: Clientes en el móvil

> **Meta**
> - Apps afectadas: `mobile`
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
- **Alta de propiedad (`site`)** dentro del cliente — es de donde cuelga, y es lo
  que SPEC-0005 necesita para poder crear una obra.
- **Edición** de los campos editables del dominio.

### No entra

- **Otorgar el photo release.** Necesita el documento firmado adjunto, y el
  dominio dice explícitamente que **no se puede setear desde el móvil sin él**.
  Se muestra si está o no está; otorgarlo es otro spec, con la subida del papel.
- **Invitar al portal del cliente.** Es el frente `cliente` y ya tiene su spec en
  `docs/specs/web/`.
- **La geocerca.** `lat`, `lng` y `geofence_radius_m` son del sitio y los usa
  asistencia; ajustarlos desde el móvil entra con el frente `campo`.
- **Fusionar duplicados.** Va a hacer falta —ver riesgos— pero no ahora.

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

- [ ] La lista sale de local: apagando la red, la búsqueda sigue funcionando.
- [ ] Ninguna pantalla de este frente importa un cliente de `lib/api/`.
- [ ] Buscar encuentra por nombre, por empresa y por teléfono.
- [ ] Crear un cliente sin señal lo deja usable de inmediato para crear una obra
      en el mismo estado sin señal.
- [ ] Cliente, propiedad y obra creados offline en ese orden llegan al servidor
      en ese orden y sin duplicarse.
- [ ] El id del cliente creado en el móvil es el mismo que queda en el servidor.
- [ ] `photo_release_granted_at` es de solo lectura: no hay forma de otorgarlo ni
      revocarlo desde esta pantalla.
- [ ] Un cliente sin `email` ni `phone` se puede guardar, y la pantalla avisa que
      no va a poder entrar al portal.
- [ ] Una propiedad nueva queda asociada a su cliente y aparece en el selector de
      sitio del alta de obra.
- [ ] Claro y oscuro correctos, y un solo naranja sólido por pantalla.
- [ ] Cero cadenas quemadas, en `en` y `es`.

## Riesgos / consideraciones

**Los duplicados van a aparecer.** Sin señal no hay forma de avisar que ese
cliente ya existe en otro dispositivo, y "Martínez" se va a cargar dos veces. No
se resuelve acá, pero conviene que el alta muestre coincidencias por nombre y
teléfono **de lo que hay en local** antes de guardar: es barato y ataja la mitad
de los casos.

**`display_name` es "como lo llama William".** El dominio no obliga a nombre y
apellido, así que el alta puede pedir un solo campo y quedarse ahí. Pedir la
ficha completa parado en un techo es lo que hace que la gente no cargue nada.

**La dirección es `jsonb`.** El dominio no fija su forma. Antes de implementar
hay que decidir qué campos tiene y dejarlo escrito, o cada consumidor —móvil,
Angular, el sitio público— va a inventar el suyo. **Esto se resuelve antes de
codear esta pantalla.**

## ADRs relacionados

- [[../../../adr/0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]] — por
  qué `email` o `phone` importan aunque sean opcionales

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-09 | borrador | Creado. Es prerequisito de datos de SPEC-0005: sin clientes y sitios en local, el alta de obra no tiene de dónde elegir. Queda abierta la forma de `billing_address`, que hay que cerrar antes de implementar. |
