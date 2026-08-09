---
id: DOM-proyecto
title: "Proyecto"
aliases: ["Proyecto"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0003", "ADR-0004"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Proyecto

## Qué es

Una obra. La unidad central del sistema: todo cuelga de acá — fotos, documentos,
horas, estimados, publicación.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `customer_id` | uuid | sí | |
| `site_id` | uuid | sí | Dónde se trabaja |
| `name` | string | sí | |
| `description` | text | no | |
| `service_type` | string | no | Techos, remodelación, etc. Alimenta el filtro del portafolio |
| `status` | enum | sí | Ver abajo |
| `client_visibility_mode` | enum | sí | `etapas` (default) o `avance` |
| `start_date` / `target_end_date` / `actual_end_date` | date | no | |
| `published_at` | timestamptz | no | |

### Estados

```
LEAD → ESTIMATED → SCHEDULED → IN_PROGRESS → COMPLETED
                        ↓            ↓
                    ON_HOLD      CANCELLED
```

Lo que ve el cliente es un mapeo de tres, no estos:

| Interno | Cliente ve |
|---|---|
| `LEAD`, `ESTIMATED`, `SCHEDULED` | Inicio |
| `IN_PROGRESS`, `ON_HOLD` | En proceso |
| `COMPLETED` | Finalizado |

### `project_assignment`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `project_id` | uuid | sí | |
| `crew_id` o `membership_id` | uuid | sí | Uno de los dos |
| `date` | date | sí | |
| `planned_headcount` | int | no | Cuántos se esperaban |

Esta tabla es la respuesta a *"no sé cuántos mandé a cada proyecto"*: lo planeado
contra lo que realmente marcó asistencia.

## Invariantes

- El `site_id` tiene que pertenecer al `customer_id`. No se cruzan.
- `client_visibility_mode` arranca en `etapas`. Pasar a `avance` es acción explícita.
- Un `WORKER` solo ve proyectos donde tiene asignación vigente. No puede enumerar
  los demás.
- `published_at` no se puede setear si el cliente no otorgó photo release.
- `CANCELLED` no borra nada: las horas trabajadas siguen siendo horas pagables.

## Comportamiento offline

Se crea desde el móvil con UUIDv7 local — es el flujo principal del prototipo.
Conflicto por última escritura gana, salvo en `status`, donde una transición
retrocedente que llega tarde desde un dispositivo se descarta.

## Eventos que emite

- `ProyectoCreado`, `EstadoCambiado`, `CuadrillaAsignada`, `ProyectoPublicado`,
  `VisibilidadCambiada`

## Relaciones con otros agregados

- [[cliente]] — de quién es
- [[cuadrilla]] — quién trabaja
- [[registro-de-tiempo]] — las horas se imputan acá
- [[contenido]] — fotos y documentos cuelgan de acá
- [[estimado]] y [[factura]] — lo que se cobra
- [[publicacion]] — cómo sale al público

## Qué NO es

- No es una tarea ni una lista de pendientes. No hay checklists ni subtareas.
- No maneja presupuesto en el sentido de control de gastos: el costo real sale de
  horas más materiales, no de un módulo de presupuesto.
- No tiene dependencias entre proyectos ni ruta crítica. Eso es Procore.

## Ejemplos

**Típico** — "Techo casa Martínez", cliente con release firmado, cuadrilla A
asignada tres días, 40 fotos, publicado al terminar.

**Borde** — Dos proyectos distintos en la misma dirección con seis meses de
diferencia: comparten `site_id`, por lo tanto comparten geocerca, y cada uno tiene
sus propias fotos y horas sin mezclarse.
