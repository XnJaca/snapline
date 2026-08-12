---
id: DEBT-0006
title: "La razón de anular una factura se exige y se tira"
aliases:
  - "DEBT-0006: La razón de anular una factura se exige y se tira"
type: tech-debt
status: abierta
severity: media
origin: "billing, construido sin spec"
apps:
  - api
trigger: "Antes de la primera factura real emitida a un cliente de William, o al escribir el spec retroactivo de billing"
created: 2026-08-12
updated: 2026-08-12
tags:
  - tech-debt
  - tech-debt/abierta
  - facturacion
---

# DEBT-0006: La razón de anular una factura se exige y se tira

## Contexto

`VoidInvoiceDto` declara `reason` como **obligatorio** —`@IsString() @IsNotEmpty()`—,
el controller lo recibe y se lo pasa al servicio. Y ahí termina: `voidInvoice` no lo
escribe en ningún lado. **No hay dónde**: `invoice` tiene `voided_at` y no tiene
`voided_reason`, ni en la entity ni en el esquema.

Encontrado el 2026-08-12 al configurar ESLint por primera vez en `apps/api`. El
parámetro sin usar era la única señal; nada más lo delataba, porque el endpoint
responde 200 y la factura queda anulada de verdad.

## Por qué importa

La regla 16 dice que una factura enviada **no se edita: se anula y se emite otra**.
Anular es la única salida, y es exactamente el momento en que hace falta saber por
qué — es la misma lógica de la regla 12 con las horas: la corrección deja rastro
porque la disputa llega después.

Hoy el sistema le pide al usuario que escriba el motivo, lo valida, y lo descarta.
Eso es peor que no pedirlo: quien lo escribe cree que quedó registrado.

## Qué hay que hacer

- Columna `voided_reason` en `invoice`, con su migración.
- Guardarla en `voidInvoice`, junto a `voided_at`.
- Regenerar `openapi.json` si la respuesta la expone.

Alternativa, si se decide que el motivo no se guarda: **sacar `reason` del DTO**.
Lo que no puede quedar es pedirlo y tirarlo.

## Workaround actual

Ninguno. Nadie ha anulado una factura todavía porque no hay facturas reales.

## Trigger

- **Antes de la primera factura real** emitida a un cliente de William.
- O **al escribir el spec retroactivo de billing**, que ya está declarado como deuda
  en el `CLAUDE.md` raíz: `catalog`, `crews`, `billing` y `reports` se construyeron
  sin spec, contra la regla 2. Este agujero es de esa familia.
