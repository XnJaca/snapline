---
id: DOM-catalogo-de-servicios
title: "Catálogo de Servicios"
aliases: ["Catálogo de Servicios"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0001"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Catálogo de Servicios

## Qué es

Los productos y servicios que la empresa vende, con su precio y su costo. Es lo que
hoy William ingresa a mano cada vez que estima.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `code` | string | no | Único por empresa si existe |
| `name` | string | sí | |
| `description` | text | no | |
| `unit` | enum | sí | `HOUR`, `SQFT`, `LINEAR_FT`, `EACH`, `JOB` |
| `unit_price_cents` | int | sí | Lo que cobra |
| `cost_cents` | int | no | Lo que le cuesta — habilita margen |
| `taxable` | bool | sí | |
| `category` | string | no | |
| `active` | bool | sí | |

## Invariantes

- Dinero en centavos enteros. Nunca punto flotante.
- Cambiar un precio **no afecta** estimados ni facturas ya emitidos: las líneas
  copian el valor. Ver [[estimado]] y [[factura]].
- Un ítem no se borra, se desactiva: puede estar referenciado en documentos viejos.

## Comportamiento offline

Se cachea para poder armar un estimado en obra sin señal. No se edita desde el móvil.

## Eventos que emite

- `ItemCreado`, `PrecioActualizado`, `ItemDesactivado`

## Relaciones con otros agregados

- [[estimado]] y [[factura]] — sus líneas se originan acá
- [[oferta-y-lead]] — las ofertas al cliente apuntan a ítems del catálogo

## Qué NO es

- No es inventario. No hay existencias, ni entradas, ni salidas.
- No maneja proveedores ni órdenes de compra.
- No calcula sales tax por jurisdicción: solo marca si el ítem es gravable.

## Ejemplos

**Típico** — "Reemplazo de teja asfáltica", `SQFT`, $4.50 el pie², costo $2.10.

**Borde** — Un ítem desactivado que sigue apareciendo en facturas del año pasado.
Se muestra correctamente porque la línea guarda su propio nombre y precio.
