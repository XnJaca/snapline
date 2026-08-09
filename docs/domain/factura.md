---
id: DOM-factura
title: "Factura y Pago"
aliases: ["Factura y Pago"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0001"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Factura y Pago

## Qué es

El cobro de la obra y lo que se recibió contra él. Reemplaza a QuickBooks.
Ver [[../adr/0001-reemplazar-quickbooks/README|ADR-0001]].

## Atributos

### `invoice`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `customer_id` / `project_id` | uuid | sí / no | |
| `estimate_id` | uuid | no | De dónde salió |
| `number` | string | sí | Secuencial por empresa |
| `status` | enum | sí | `DRAFT` → `SENT` → `PARTIAL` → `PAID`, más `OVERDUE` y `VOID` |
| `issued_at` / `due_at` | timestamptz | no | |
| `subtotal_cents` / `tax_cents` / `total_cents` / `balance_cents` | int | sí | Calculados en el servidor |

### `invoice_line`

Mismos snapshots que [[estimado]]: nombre, descripción, unidad, precio y
gravabilidad copiados como valor.

### `payment`

| Atributo | Notas |
|---|---|
| `amount_cents` | |
| `method` | `CHECK`, `CASH`, `ACH`, `CARD`, `ZELLE` |
| `received_at`, `reference` | |

### `document_counter`

`company_id`, `doc_type`, `next_number`. Con lock de fila.

## Invariantes

- **Las líneas copian, no referencian.** Igual que en el estimado, y por la misma
  razón: cambiar un precio no puede reescribir facturas emitidas.
- **Los totales y el balance se recalculan en el servidor.** Nunca se acepta un
  total del cliente.
- **Una factura enviada no se edita.** Se anula (`VOID`) y se emite otra. Una
  factura es un documento, no un formulario.
- **Numeración con contador por empresa y lock**, nunca `SERIAL` global: los
  números de una empresa no pueden saltar porque otra insertó.
- `balance_cents` = `total_cents` menos la suma de pagos. Es derivado, y se recalcula,
  no se edita a mano.
- Un pago no puede exceder el balance.
- `PAID` es consecuencia de que el balance llegue a cero, no un estado que se setee.

## Comportamiento offline

No se emite desde el móvil. Se consulta en solo lectura. Registrar un pago recibido
en obra sí se permite offline, encolado con idempotencia — cobrar dos veces por un
reintento de red sería el peor bug posible del módulo.

## Eventos que emite

- `FacturaEmitida`, `FacturaEnviada`, `PagoRegistrado`, `FacturaPagada`,
  `FacturaAnulada`, `FacturaVencida`

## Relaciones con otros agregados

- [[estimado]] — de dónde nace
- [[cliente]] — a quién se le cobra
- [[proyecto]] — qué obra cobra
- [[catalogo-de-servicios]] — origen de las líneas

## Qué NO es

- **No cobra con tarjeta** en la primera versión. Registra el pago recibido.
- No calcula sales tax por jurisdicción. Tasa configurable y bandera por línea; el
  tratamiento en Maryland lo confirma el contador de William.
- No hace contabilidad: no hay libro mayor, ni asientos, ni conciliación bancaria.
- No calcula nómina.

## Ejemplos

**Típico** — Factura generada desde un estimado aceptado, $8,400, pago por cheque a
los 15 días, pasa a `PAID`.

**Borde** — Pago parcial de $4,000: `PARTIAL`, balance $4,400. Un segundo pago la
cierra.

**Borde hostil** — El cliente manda un `total_cents` manipulado en el request. El
servidor lo ignora y recalcula desde las líneas.
