---
id: DEBT-0013
title: "Ninguna tabla local de Drift declara índices"
aliases:
  - "DEBT-0013: Ninguna tabla local de Drift declara índices"
type: tech-debt
status: abierta
severity: baja
origin: "SPEC-0012"
apps:
  - mobile
trigger: "La primera obra con más de un mes de fotos y jornadas en un teléfono real, o el primer reporte de que una pantalla tarda en abrir"
created: 2026-09-03
updated: 2026-09-03
tags:
  - tech-debt
  - campo
---

# DEBT-0013: Ninguna tabla local de Drift declara índices

## Contexto

`apps/mobile/lib/data/local/tables.dart` define catorce tablas y **ninguna
declara un índice**. Toda consulta que filtra por `project_id`, por
`membership_id` o por fecha resuelve con un scan lineal de la tabla entera.

Hoy no se nota: una obra de prueba tiene decenas de filas. Con los datos de una
temporada —fotos, jornadas, notas e hitos de varias obras a lo largo de meses—
cada apertura de pantalla recorre todo.

## Dónde pega primero

El hilo de Avance (`progress_repository.dart`) es la consulta más pesada del
teléfono: un `UNION ALL` de cuatro fuentes más la bandeja, ordenado y paginado en
la base. La paginación se resolvió bien —el `LIMIT` está en SQL y no en Dart—,
pero **cada página sigue escaneando las cinco tablas** para juntar las filas del
proyecto antes de ordenar.

El resumen de la misma pantalla (`watchResumen`) corre diez subconsultas
escalares sobre las mismas tablas, y se re-ejecuta entero cada vez que Drift
detecta un cambio en cualquiera de las seis que observa.

## Por qué no se arregló en SPEC-0012

El defecto es del esquema, no de las dos tablas que trajo este spec. Indexar solo
`project_status_changes` y `project_updates` dejaría sin índice a `media_assets`
y `time_entries`, que son las que más filas acumulan y las que esa misma consulta
recorre. Sería trabajo a medias con la apariencia de estar hecho.

## Cómo se cierra

Un solo paso de esquema que agregue los índices que las consultas reales piden.
Los candidatos que salen de leer los repositorios:

| Tabla | Índice |
|---|---|
| `media_assets` | `(project_id, captured_at)` |
| `time_entries` | `(project_id, clock_in_at)`, `(membership_id, clock_in_at)` |
| `project_updates` | `(project_id, published_at)` |
| `project_status_changes` | `(project_id, device_recorded_at)` |
| `project_assignments` | `(project_id, work_date)` |
| `outbox_operations` | `(type, target_id)` |

Se mide antes y después con una base sembrada con volumen de una temporada; sin
esa medición no hay forma de saber si los índices elegidos son los que hacían
falta.
