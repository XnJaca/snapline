---
id: DEBT-0010
title: "El panel no puede mostrar quién marcó las horas ni quién es el capataz"
aliases:
  - "DEBT-0010: El panel no puede mostrar quién marcó las horas ni quién es el capataz"
type: tech-debt
status: abierta
severity: media
origin: "SPEC-0008"
apps:
  - api
  - web
trigger: "El spec de la pantalla de Horas, o el de Cuadrillas, lo que llegue primero"
created: 2026-08-31
updated: 2026-08-31
tags:
  - tech-debt
  - tech-debt/abierta
  - contrato
---

# DEBT-0010: El panel no puede mostrar quién marcó las horas ni quién es el capataz

## Contexto

Las ocho pantallas del panel leen los endpoints que ya existen. Dos de ellas se
quedan cortas porque el contrato no devuelve el nombre de la persona:

- **`GET /time-entries`** devuelve `projectId` y `membershipId` y nada embebido.
  El nombre de la obra se puede resolver cruzando con `GET /projects`, pero el de
  quien marcó **no tiene de dónde salir**: no hay endpoint de membresías.
- **`GET /crews`** embebe la membresía del capataz pero **sin su `user`**, así que
  llega `foreman.userId` y nunca `foreman.user.name`.

## Qué no se hizo

No se tocaron esos dos endpoints. Cargar la relación en `/time-entries` cambia el
contrato que el móvil ya consume, y hay trabajo en vuelo sobre esos modelos Dart
en `feature/mobile-0011-horas`. Tocarlo desde la rama del panel era la forma de
romperle la rama a otro.

## Workaround actual

- **Horas** muestra la obra —resuelta en el cliente contra `/projects`— y en lugar
  de la persona muestra `method`: si marcó ella misma, el capataz o la oficina.
  Es lo más cerca de "quién" que el contrato permite hoy.
- **Cuadrillas** muestra nombre y color, sin columna de capataz.

## Costo de resolverla

Chico y en el API, no en el panel:

| Endpoint | Cambio |
|---|---|
| `/time-entries` | `relations: { project: true, membership: { user: true } }` en el `find` del listado |
| `/crews` | Extender la relación del capataz hasta `user` |

En los dos casos hay que mirar qué se serializa: `pay_rate_cents` y
`password_hash` van con `select: false`, así que no viajan, pero el `app_user`
embebido saca correo y teléfono de la persona a una pantalla donde hoy no están.

## Trigger

**El spec de la pantalla de Horas**, que es el que va a pedir aprobar horas y ahí
no saber de quién son deja de ser un detalle. O el de Cuadrillas, si llega antes.
