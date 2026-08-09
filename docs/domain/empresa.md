---
id: DOM-empresa
title: "Empresa"
aliases: ["Empresa"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0002"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Empresa

## Qué es

El inquilino del sistema. Una empresa contratista con su gente, sus proyectos y sus
clientes, aislada del resto.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `name` | string | sí | Nombre comercial |
| `legal_name` | string | no | El que va en las facturas |
| `timezone` | string | sí | IANA. `America/New_York` para William |
| `currency` | string | sí | ISO 4217. `USD` |
| `address` | jsonb | no | Dirección fiscal |
| `logo_asset_id` | uuid | no | Para facturas y sitio público |
| `public_site_slug` | string | no | Único global; identifica su portafolio |
| `settings` | jsonb | sí | Radio de geocerca por default, método de asistencia |

## Invariantes

- `public_site_slug` es único en todo el sistema, no por empresa.
- `timezone` no puede ser nulo: todo reporte de horas se calcula contra ella, nunca
  contra la zona del navegador de quien abre el reporte.
- Cambiar `currency` con facturas emitidas está prohibido.

## Comportamiento offline

No se crea ni modifica desde el móvil. Se descarga y se cachea.

## Eventos que emite

- `EmpresaCreada`
- `EmpresaConfiguracionActualizada`

## Relaciones con otros agregados

- Padre de absolutamente todo. Su `id` es el `company_id` de la regla 1.
- [[usuario-y-membresia]] — la gente entra por membresía, no directo

## Qué NO es

- No es un usuario. Una persona puede pertenecer a varias empresas.
- No maneja facturación **de** la plataforma (lo que la empresa nos paga a nosotros).
  Eso es otra cosa y todavía no existe.

## Ejemplos

**Típico** — Professional Construction LLC, Maryland, `America/New_York`, USD.

**Borde** — Una empresa sin `public_site_slug` todavía: puede operar completa y no
publicar nada. El frente de publicidad es opcional a nivel de datos.
