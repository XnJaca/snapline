---
id: DOM-acceso-del-cliente
title: "Acceso del Cliente"
aliases: ["Acceso del Cliente"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0004"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Acceso del Cliente

## Qué es

Cómo el dueño de la casa entra a ver su proyecto, y qué se le muestra.
Ver [[../adr/0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]].

## Atributos

### `client_access`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `customer_id` | uuid | sí | |
| `project_id` | uuid | no | Nulo = acceso a todos sus proyectos |
| `token_hash` | string | sí | **Hasheado, nunca en claro** |
| `expires_at` | timestamptz | sí | |
| `last_seen_at` | timestamptz | no | |
| `claimed_user_id` | uuid | no | Si reclamó cuenta |
| `revoked_at` | timestamptz | no | |

### `project_update`

| Atributo | Notas |
|---|---|
| `project_id`, `author_membership_id` | |
| `body`, `assets[]` | |
| `visibility` | Hereda la escalera de [[contenido]] |
| `approved_by`, `published_at` | **Nada llega al cliente sin aprobación explícita** |

## Invariantes

- **El token se guarda hasheado.** Es un credencial que viaja por SMS.
- Expira. Un link sin vencimiento es un acceso permanente a datos de una obra.
- El endpoint que lo consume lleva **rate limit**: sin eso es fuerza bruta.
- **No viaja en query string visible** — se filtra por `Referer` y por analytics.
- Un portador de token **no puede ver contenido `INTERNAL`**, ni de su proyecto ni
  de ningún otro.
- Revocar el acceso es inmediato y no depende de la expiración.
- Ningún `project_update` es visible sin `approved_by` y `published_at`.
- Si `client_visibility_mode` del proyecto es `etapas`, el cliente ve solo el estado
  mapeado a tres — ningún update ni foto, aunque estén aprobados.

## Comportamiento offline

No aplica: el portal es web, no hay app de cliente.

## Eventos que emite

- `AccesoGenerado`, `AccesoUsado`, `CuentaReclamada`, `AccesoRevocado`,
  `ActualizacionPublicada`

## Relaciones con otros agregados

- [[cliente]] — de quién es el acceso
- [[proyecto]] — qué obra ve y en qué modo
- [[contenido]] — qué assets alcanza
- [[oferta-y-lead]] — qué se le ofrece ahí mismo

## Qué NO es

- No es una membresía. El cliente no tiene rol en la empresa.
- No es un chat. No hay mensajería bidireccional.
- No permite al cliente subir nada.

## Ejemplos

**Típico** — SMS con link, el cliente abre y ve "En proceso". Nada más, porque el
proyecto está en modo `etapas`.

**Borde** — Cliente que reclama cuenta y luego pierde el link original: entra con
su cuenta y ve el historial. El token viejo sigue expirando por su cuenta.

**Borde hostil** — Alguien prueba tokens al azar contra el endpoint. El rate limit
lo corta, y los tokens hasheados hacen que una fuga de base de datos no entregue
accesos utilizables.
