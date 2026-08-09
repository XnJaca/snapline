---
id: SPEC-0001
title: "Catálogo de Servicios"
aliases:
  - "SPEC-0001: Catálogo de Servicios"
type: spec
platform: web
status: implementado
goal: "William arma un estimado eligiendo de su catálogo en vez de escribir cada ítem a mano, y ve el margen de cada uno."
apps: [api]
depends_on: []
domain: [catalogo-de-servicios]
frente: administrativo
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/implementado
---

# SPEC-0001: Catálogo de Servicios

> **Spec retroactivo.** Se escribió después de implementar, contra la regla 2.
> Queda como registro de lo que hay; los próximos van antes del código.

## Problema

William estima a mano cada vez. Reescribe los mismos ítems, con precios que
recuerda de memoria, y **no sabe cuánto le queda de margen** porque nunca anotó
el costo.

## Alcance

### Entra
- Ítems con nombre, unidad (`HOUR`, `SQFT`, `LINEAR_FT`, `EACH`, `JOB`), precio y costo
- Marca de gravable por ítem
- Categoría para agrupar
- Desactivar sin borrar

### No entra
- Inventario: no hay existencias ni movimientos
- Proveedores ni órdenes de compra
- Cálculo de impuesto por jurisdicción — solo la marca de gravable

## Modelo de dominio afectado

- [[catalogo-de-servicios]]

## Contrato de API

```http
GET    /api/service-items?includeInactive=true
POST   /api/service-items
PATCH  /api/service-items/:id
DELETE /api/service-items/:id      → desactiva, no borra
```

## Criterios de aceptación

- [x] Un ítem desactivado sigue apareciendo correctamente en documentos ya emitidos
- [x] `costCents` permite derivar margen, y es opcional
- [x] Los precios son enteros de centavos, nunca punto flotante
- [x] Solo `OWNER` y `ADMIN` escriben; `ACCOUNTANT` lee

## Riesgos / consideraciones

Un ítem **no se borra nunca**: puede estar referenciado desde estimados y facturas
emitidos. Se desactiva.

## ADRs relacionados

- [[../../adr/0001-reemplazar-quickbooks/README|ADR-0001]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | implementado | Spec retroactivo sobre código ya en `main` |
