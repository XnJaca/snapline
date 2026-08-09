---
id: DOM-estimado
title: "Estimado"
aliases: ["Estimado"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0001"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Estimado

## Qué es

La cotización que se le manda al cliente antes de trabajar. Al aceptarse, se
convierte en la base de la factura.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `customer_id` | uuid | sí | |
| `project_id` | uuid | no | Puede existir antes que el proyecto |
| `number` | string | sí | Secuencial por empresa |
| `status` | enum | sí | Ver abajo |
| `issued_at` / `expires_at` | timestamptz | no | |
| `subtotal_cents` / `tax_cents` / `total_cents` | int | sí | **Calculados en el servidor** |
| `terms` | text | no | Acá va la cláusula de photo release |
| `accepted_at` | timestamptz | no | |
| `accepted_signature_asset_id` | uuid | no | |
| `accepted_ip` | inet | no | |

```
DRAFT → SENT → VIEWED → ACCEPTED
                     ↘ DECLINED
                     ↘ EXPIRED
```

### `estimate_line`

| Atributo | Notas |
|---|---|
| `service_item_id` | Solo para reportes — **no** se usa para mostrar |
| `name_snapshot`, `description_snapshot`, `unit_snapshot` | Copiados |
| `qty`, `unit_price_cents_snapshot`, `taxable_snapshot` | Copiados |
| `amount_cents` | Calculado en el servidor |

## Invariantes

- **Las líneas copian, no referencian.** Nombre, descripción, unidad, precio y
  gravabilidad se guardan como valor. Referenciar el catálogo vivo significa que
  cambiar un precio reescribe cotizaciones del año pasado.
- **Los totales se recalculan en el servidor.** Nunca se guarda un total que mandó
  el cliente.
- La numeración usa un contador por empresa con lock de fila, no `SERIAL` global.
- Un estimado `ACCEPTED` no se edita. Se emite otro.
- La aceptación registra firma, fecha e IP: es lo que lo vuelve exigible.

## Comportamiento offline

Se arma en el móvil con el catálogo cacheado, en estado `DRAFT`. Enviarlo requiere
red. Un `DRAFT` creado offline sube con UUIDv7 y se numera **en el servidor**, al
enviarse — nunca en el dispositivo, porque la numeración no puede tener huecos.

## Eventos que emite

- `EstimadoCreado`, `EstimadoEnviado`, `EstimadoVisto`, `EstimadoAceptado`,
  `EstimadoRechazado`

## Relaciones con otros agregados

- [[cliente]] — a quién se le emite
- [[catalogo-de-servicios]] — de dónde salen las líneas
- [[factura]] — en qué se convierte
- [[proyecto]] — qué obra ampara

## Qué NO es

- No es un contrato legal completo. Los términos son texto, no cláusulas gestionadas.
- No maneja órdenes de cambio. Un cambio de alcance es un estimado nuevo.
- No cobra nada.

## Ejemplos

**Típico** — Tres líneas del catálogo, total $8,400, enviado por email, aceptado
con firma a los dos días. El proyecto pasa a `SCHEDULED`.

**Borde** — El precio del catálogo sube 10% una semana después. El estimado
aceptado sigue mostrando el precio viejo, porque lo copió.
