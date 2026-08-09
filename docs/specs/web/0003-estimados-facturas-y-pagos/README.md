---
id: SPEC-0003
title: "Estimados, Facturas y Pagos"
aliases:
  - "SPEC-0003: Estimados, Facturas y Pagos"
type: spec
platform: web
status: implementado
goal: "William emite un estimado desde su catálogo, lo convierte en factura al aceptarse, y el monto no cambia nunca aunque después cambie el precio del catálogo."
apps: [api]
depends_on: [SPEC-0001]
domain: [estimado, factura, catalogo-de-servicios, cliente]
frente: administrativo
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/implementado
---

# SPEC-0003: Estimados, Facturas y Pagos

> **Spec retroactivo.** Se escribió después de implementar, contra la regla 2.

## Problema

William paga QuickBooks y estima a mano igual, porque aprenderlo cuesta más que
hacerlo mal. Ver [[../../adr/0001-reemplazar-quickbooks/README|ADR-0001]].

## Alcance

### Entra
- Estimado → enviar → aceptar (con firma e IP) → factura
- Líneas del catálogo o libres, con precio manual
- Numeración secuencial **por empresa**
- Pagos parciales con saldo derivado, y anulación

### No entra
- **Cobro con tarjeta.** Se registra el pago recibido; Stripe no está en alcance
- Sales tax por jurisdicción: hay tasa configurable y marca por línea
- Contabilidad: sin libro mayor, sin asientos, sin conciliación
- Órdenes de cambio — un cambio de alcance es un estimado nuevo

## Flujo

```
DRAFT → SENT → VIEWED → ACCEPTED → factura → SENT → PARTIAL → PAID
                     ↘ DECLINED / EXPIRED                   ↘ VOID
```

## Contrato de API

```http
POST /api/estimates · POST /api/estimates/:id/send
POST /api/estimates/:id/accept · POST /api/estimates/:id/invoice
POST /api/invoices · POST /api/invoices/:id/send
POST /api/invoices/:id/payments · POST /api/invoices/:id/void
```

## Criterios de aceptación

- [x] **Cambiar el precio del catálogo no altera un documento emitido** — la línea
      copia nombre, unidad, precio y gravabilidad. Cubierto por e2e
- [x] Los totales los calcula el servidor; mandarlos en el body no tiene efecto
- [x] La numeración usa contador por empresa con lock de fila, no `SERIAL` global
- [x] Un estimado aceptado se factura una sola vez
- [x] Un pago mayor al saldo se rechaza; el mismo `idempotencyKey` no cobra dos veces
- [x] Una factura enviada no se edita: se anula y se emite otra

## Riesgos / consideraciones

**Bloqueante para uso real, no técnico:** el contador de William tiene que aceptar
estos datos. Hablar con esa persona antes de que salga la primera factura, y
confirmar con ella el tratamiento de sales tax en Maryland. Ver [[../../PENDIENTES]].

## ADRs relacionados

- [[../../adr/0001-reemplazar-quickbooks/README|ADR-0001]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | implementado | Spec retroactivo sobre código ya en `main` |
