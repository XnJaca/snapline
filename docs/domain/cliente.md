---
id: DOM-cliente
title: "Cliente"
aliases: ["Cliente"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0004"]
created: 2026-08-08
updated: 2026-08-08
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
| `source` | enum | no | `referido`, `web`, `redes`, `otro` |
| `photo_release_granted_at` | timestamptz | no | **Habilita publicar** |
| `photo_release_document_id` | uuid | no | El papel firmado |
| `notes` | text | no | |

### `site` — la propiedad

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `customer_id` | uuid | sí | |
| `address` | jsonb | sí | |
| `lat` / `lng` | numeric | no | Centro de la geocerca |
| `geofence_radius_m` | int | no | Default de la empresa si es nulo |

## Invariantes

- **`photo_release_granted_at` es lo único que habilita `PUBLIC`** en
  [[contenido]], y la restricción vive en la base de datos, no en el formulario.
- La geocerca pertenece al **sitio**, no al proyecto: el mismo cliente puede tener
  tres trabajos en la misma casa y la ubicación es una sola.
- Revocar el photo release **despublica** el contenido público asociado. No es un
  campo que solo aplique hacia adelante.
- Para invitar al portal hace falta `email` o `phone`.

## Comportamiento offline

Se crea desde el móvil (William registra un cliente parado en la obra), con UUIDv7
local. Conflicto por última escritura gana. El `photo_release_granted_at` **no** se
puede setear desde el móvil sin el documento firmado adjunto.

## Eventos que emite

- `ClienteCreado`, `PhotoReleaseOtorgado`, `PhotoReleaseRevocado`, `SitioAgregado`

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

**Típico** — Dueño de casa, teléfono y email, `source: redes`, release firmado al
aceptar el estimado.

**Borde** — Un cliente que otorgó el release y después pide que bajen las fotos. Al
revocar, todo lo `PUBLIC` de sus proyectos vuelve a `CLIENT` y el sitio deja de
mostrarlo. El contenido no se borra: cambia de nivel.
