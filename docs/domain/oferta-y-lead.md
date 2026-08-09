---
id: DOM-oferta-y-lead
title: "Oferta y Lead"
aliases: ["Oferta y Lead"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0004"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Oferta y Lead

## Qué es

Los servicios que se le ofrecen a un cliente existente desde su portal, y las
solicitudes que eso genera.

El cliente que ya pagó una obra es el lead más barato que existe. Este agregado es
el que lo mide.

## Atributos

### `service_offer`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `service_item_id` | uuid | no | Del catálogo, o texto libre |
| `title` / `pitch` | string | sí | |
| `active` | bool | sí | |
| `target` | jsonb | no | A qué segmento aplica |

### `lead`

| Atributo | Notas |
|---|---|
| `customer_id`, `offer_id`, `source_project_id` | |
| `status` | `nuevo`, `contactado`, `convertido`, `descartado` |
| `converted_project_id` | Cierra el ciclo |

Se registran impresiones y solicitudes: sin medirlo no se sabe si el frente funciona.

## Invariantes

- Una oferta solo se muestra a un cliente con acceso vigente.
- `converted_project_id` es lo que prueba que el ciclo cierra. Sin ese dato, el
  frente de venta cruzada es una corazonada.
- Un lead no crea un proyecto solo: alguien lo convierte a mano.

## Comportamiento offline

No aplica.

## Eventos que emite

- `OfertaMostrada`, `LeadGenerado`, `LeadConvertido`, `LeadDescartado`

## Relaciones con otros agregados

- [[acceso-del-cliente]] — dónde se muestra
- [[catalogo-de-servicios]] — qué se ofrece
- [[cliente]] — a quién
- [[proyecto]] — de dónde salió y en qué se convirtió

## Qué NO es

- No es un CRM. No hay pipeline, etapas configurables ni automatizaciones.
- No manda campañas. No hay email marketing acá.
- No califica leads ni les pone puntaje.

## Ejemplos

**Típico** — Terminado un techo, al cliente se le ofrece mantenimiento de canoas.
Solicita información, se genera un lead, William lo llama.

**Borde** — Un lead que nunca se convierte: queda en `descartado` y sigue contando
en la tasa de conversión de la oferta, que es justamente el dato útil.
