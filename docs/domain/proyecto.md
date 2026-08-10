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
                                   ⇅
                                ON_HOLD

CANCELLED ← desde cualquier estado vivo
```

**Las transiciones válidas, completas.** El diagrama de arriba muestra el camino
normal; esta tabla es la que vale, y es la que valida el servidor:

| Desde | Puede pasar a |
|---|---|
| `LEAD` | `ESTIMATED`, `CANCELLED` |
| `ESTIMATED` | `SCHEDULED`, `CANCELLED` |
| `SCHEDULED` | `IN_PROGRESS`, `ON_HOLD`, `CANCELLED` |
| `IN_PROGRESS` | `COMPLETED`, `ON_HOLD`, `CANCELLED` |
| `ON_HOLD` | `IN_PROGRESS`, `CANCELLED` |
| `COMPLETED` | — final |
| `CANCELLED` | — final |

Tres cosas que la tabla decide y el diagrama no decía:

- **De `ON_HOLD` se vuelve.** Llueve una semana y la obra se pausa; después se
  reanuda. Sin esta transición una obra en pausa quedaba trabada para siempre.
- **Se cancela desde cualquier estado vivo**, no solo desde `IN_PROGRESS`. El caso
  más común es el más temprano: el cliente no acepta el estimado.
- **No se retrocede y no se salta.** Terminada no se reabre —si se reabriera,
  "terminada" dejaría de ser confiable para el reporte y para publicar— y no se
  puede ir de `LEAD` a `IN_PROGRESS` sin pasar por el medio.

Decidido el 2026-08-10, al implementar
[[../specs/mobile/0005-proyectos-en-el-movil/README|SPEC-0005]]: el selector del
móvil necesitaba la tabla y el diagrama no alcanzaba para derivarla.

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
- **`customer_id` y `site_id` se fijan al crear y no se editan.** Una obra tiene
  horas, fotos, estimados y facturas colgando: cambiarle el cliente reasigna todo
  eso a otra persona, y eso no es un campo de formulario. Si se eligió mal, se
  cancela la obra y se crea de nuevo — que además deja rastro, igual que una
  factura enviada que se anula en vez de editarse (regla 16).
  *Decidido el 2026-08-10, al encontrar que el formulario de edición los ofrecía y
  el servidor los descartaba en silencio.*
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
