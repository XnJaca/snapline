---
id: DOM-cliente
title: "Cliente"
aliases: ["Cliente"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0004"]
created: 2026-08-08
updated: 2026-09-01
tags: [domain, domain/borrador]
---

# Cliente

## Qué es

La persona o empresa que contrata la obra, junto con las propiedades donde se
trabaja.

## Atributos

### `customer`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `display_name` | string | sí | Como lo llama William |
| `first_name` / `last_name` | string | no | |
| `company_name` | string | no | Si es empresa |
| `email` / `phone` | string | no | Al menos uno para el portal |
| `billing_address` | jsonb | no | |
| `source` | enum | no | `REFERRAL`, `WEB`, `SOCIAL`, `REPEAT`, `OTHER` |
| `notes` | text | no | |

### `site` — la propiedad

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `customer_id` | uuid | sí | |
| `address` | jsonb | sí | |
| `lat` / `lng` | numeric | no | Centro de la geocerca |
| `geofence_radius_m` | int | no | Default de la empresa si es nulo |

### `address` — la forma del `jsonb`

**La misma para `customer.billing_address` y `site.address`.** Un solo tipo, un
solo formulario, un solo modelo en los tres consumidores.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `line1` | string | sí | Calle y número |
| `line2` | string | no | Apartamento, unidad, suite |
| `city` | string | sí | |
| `state` | string | sí | **En Estados Unidos y Canadá**, el código de dos letras: `MD`. En el resto, el nombre de la provincia: `San José` |
| `postal_code` | string | sí | |
| `country` | string | sí | ISO de dos letras, default `US` |

Es el mínimo que imprime una factura correcta en Estados Unidos. `country` está
desde el principio por la misma razón que la moneda no se concatena a mano: sale
gratis hoy y es caro después.

**Va declarado como DTO en el API**, no como `jsonb` suelto: si el contrato no
declara su forma, `openapi.json` lo emite vacío y el cliente generado lo tipa
`dynamic` — parsea la dirección, la descarta y no falla. Ver ADR-0007 y la
regla 8.

## Invariantes

- La geocerca pertenece al **sitio**, no al proyecto: el mismo cliente puede tener
  tres trabajos en la misma casa y la ubicación es una sola.
- Para invitar al portal hace falta `email` o `phone`.
- **Un cliente con historia no se borra.** Retiene una obra no borrada en
  cualquier estado —terminada y cancelada incluidas, porque cancelado no es lo
  mismo que borrado— y todo estimado o factura **enviados**. Un `DRAFT` no
  retiene: es editable y borrable, así que no es historia todavía. La
  comprobación vive en la base, no en el servicio, porque el borrado es suave y
  la clave foránea no lo atrapa.

- **Las propiedades se van con el cliente.** El agregado es el cliente *junto con
  las propiedades donde se trabaja*, así que borrarlo cascadea el borrado suave de
  sus `site`. Es seguro por construcción: lo único que apunta a `site` es
  `project.site_id`, y un cliente con cualquier obra viva no llega a borrarse.

- **El cliente no autoriza la publicación.** Quién decide qué sale al portafolio es
  la empresa, no él. Ver [[contenido]] y la entrada del 2026-08-12 en
  [[../DECISIONES]].

## Comportamiento offline

Se crea desde el móvil (William registra un cliente parado en la obra), con UUIDv7
local. Conflicto por última escritura gana.

## Eventos que emite

- `ClienteCreado`, `SitioAgregado`

## Relaciones con otros agregados

- [[proyecto]] — sus obras
- [[estimado]] y [[factura]] — se le emiten a él
- [[acceso-del-cliente]] — cómo entra al portal
- [[oferta-y-lead]] — a quién se le ofrece

## Qué NO es

- **No es un usuario del sistema.** No tiene membresía ni rol; entra por token.
- No es un CRM. No hay pipeline de ventas, etapas ni seguimiento de oportunidades.
- No guarda medios de pago.

## Ejemplos

**Típico** — Dueño de casa, teléfono y email, `source: redes`, dado de alta desde el
móvil el día que se fue a cotizar.

**Borde** — El mismo cliente se crea en la obra sin señal y se corrige desde la web
media hora después, antes de que el teléfono sincronice. Gana la última escritura y
no queda conflicto: es un cliente, no un [[registro-de-tiempo]].

**Borde hostil** — Un cliente pide que bajen las fotos de su obra. No hay campo que
revocar: se bajan bajando el contenido, en [[contenido]]. Que la decisión sea de la
empresa no la vuelve irreversible.
