---
id: ADR-0001
title: "Reemplazar QuickBooks en vez de integrarlo"
aliases:
  - "ADR-0001: Reemplazar QuickBooks en vez de integrarlo"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
---

# ADR-0001: Reemplazar QuickBooks en vez de integrarlo

## Contexto

William paga QuickBooks Online y ahí vive su contabilidad: clientes, estimados,
facturas. Pero declaró que aprenderlo le resulta demasiado tedioso, y termina
estimando e ingresando productos y servicios a mano.

Ese es el síntoma exacto de la tesis del producto: la herramienta hace lo que él
necesita y aun así no la usa, porque la curva no la paga un contratista que trabaja
en obra. Cualquier cosa que construyamos que necesite tutorial pierde por la misma
razón.

## Decisión

Construimos **estimados, facturas y pagos nativos**. William deja de pagar
QuickBooks. No hay integración con la API de Intuit.

## Alternativas consideradas

### Alternativa A — Integrar vía QBO API

Nosotros seríamos el front simple (catálogo, estimado en tres taps desde el
proyecto) y QuickBooks seguiría siendo la fuente contable. El contador no cambia
nada de lo que hace hoy, y evitábamos el pantano de impuestos y cumplimiento.

**Por qué no:** deja a William pagando una herramienta que no usa, y nos ata a la
API de Intuit y a su OAuth para el frente comercial completo. La sincronización
bidireccional de clientes e ítems es trabajo permanente, no una vez.

### Alternativa B — Nativo ahora, exportar después

Estimados y facturas propios sin integración, y el contador recibe CSV o PDF.

**Por qué no:** es la misma decisión que tomamos, pero fingiendo que es temporal.
Si el contador no acepta los datos, exportar no lo arregla.

## Consecuencias

### Positivas

- William deja de pagar QuickBooks — argumento de venta directo y medible.
- El catálogo de servicios con costo habilita margen por proyecto, que hoy no tiene
  porque estima a mano.
- Sin dependencia de un tercero en el frente que factura.

### Negativas / Costos

- Heredamos numeración fiscal, sales tax y la conversación con el contador.
- Es un producto entero por sí solo: es la fase más grande del roadmap.

### Riesgos

- **El contador de William tiene que aceptar los datos.** Si no, la factura no
  sirve aunque el software esté impecable. Mitigación: hablar con esa persona
  **antes** de construir facturación. Es la conversación más barata del proyecto.
- **Sales tax en Maryland.** En servicios de mejora de propiedad real la regla no
  es la misma que en venta de bienes. Mitigación: tasa configurable y bandera por
  línea; el tratamiento lo confirma el contador y queda escrito en el modelo.

## Impacto en el modelo

- [[../../domain/catalogo-de-servicios|catalogo-de-servicios]]
- [[../../domain/estimado|estimado]]
- [[../../domain/factura|factura]]

## Referencias

- Reunión con William del 2026-08-08. Ver [[../../DECISIONES]].
