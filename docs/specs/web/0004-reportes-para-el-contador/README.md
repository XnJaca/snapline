---
id: SPEC-0004
title: "Reportes para el Contador"
aliases:
  - "SPEC-0004: Reportes para el Contador"
type: spec
platform: web
status: implementado
goal: "William deja de armar a mano el paquete de horas para el contador: lo saca del sistema con la tarifa que estaba vigente cuando aprobó cada turno."
apps: [api]
depends_on: []
domain: [registro-de-tiempo, proyecto, factura]
frente: reportes
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/implementado
---

# SPEC-0004: Reportes para el Contador

> **Spec retroactivo.** Se escribió después de implementar, contra la regla 2.

## Problema

Textual de William: junta todo a mano para mandárselo al contador y hacer payroll.
Es trabajo manual, mensual, y propenso a error justo donde el error se paga.

## Alcance

### Entra
- Timesheet por trabajador, proyecto y período, **solo con horas aprobadas**
- Horas, tarifa congelada y bruto
- Cuántos registros del período traen bandera
- Costo real por proyecto: mano de obra contra lo facturado y lo cotizado

### No entra
- **Cálculo de nómina.** Retenciones, impuestos y pagos los hace el contador.
  Esa línea no se cruza — ver "Qué NO somos" en [[../../product/vision]]
- Horas extra y reglas de overtime: son cálculo de nómina
- Exportar a formatos de terceros

## Contrato de API

```http
GET /api/reports/timesheet?from=2026-08-01&to=2026-09-01
GET /api/reports/job-cost
```

## Criterios de aceptación

- [x] Solo entran registros `APPROVED` y con salida marcada
- [x] Usa `pay_rate_cents_snapshot`, no la tarifa vigente: subir el pago no
      recalcula meses cerrados
- [x] Descuenta `break_minutes`
- [x] `ACCOUNTANT` puede leerlos y **no tiene acceso a fotos**

## Riesgos / consideraciones

El reporte es tan bueno como la aprobación previa. Si se aprueban registros con
bandera sin mirarlos, el paquete sale prolijo y equivocado. Por eso la columna de
banderas va en el mismo reporte.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | implementado | Spec retroactivo sobre código ya en `main` |
