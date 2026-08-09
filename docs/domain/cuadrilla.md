---
id: DOM-cuadrilla
title: "Cuadrilla"
aliases: ["Cuadrilla"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0003"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Cuadrilla

## Qué es

Un grupo de trabajadores que se asigna junto a un proyecto. William tiene dos.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `name` | string | sí | |
| `foreman_membership_id` | uuid | no | Quién la lidera |
| `color` | string | no | Para distinguirla en el calendario |

### `crew_member`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `crew_id` | uuid | sí | |
| `membership_id` | uuid | sí | |
| `from_date` | date | sí | |
| `to_date` | date | no | Nulo = sigue en la cuadrilla |

## Invariantes

- **La pertenencia lleva fechas.** La gente rota entre cuadrillas y un reporte de
  marzo tiene que reflejar quién estaba en marzo, no quién está hoy.
- Un `membership` no puede estar en dos cuadrillas con rangos de fecha solapados.
- El `foreman_membership_id` tiene que ser miembro de la cuadrilla que lidera.

## Comportamiento offline

Se cachea en el dispositivo. El foreman necesita ver a su gente sin señal para
poder marcar por ellos.

## Eventos que emite

- `CuadrillaCreada`, `MiembroAgregado`, `MiembroRetirado`

## Relaciones con otros agregados

- [[usuario-y-membresia]] — sus miembros
- [[proyecto]] — se asigna a proyectos por fecha

## Qué NO es

- No es un rol ni un permiso. El rol vive en la membresía.
- No define quién puede ver qué: eso lo decide la asignación al proyecto.
- No es un turno. Cuándo trabaja está en la asignación, no acá.

## Ejemplos

**Típico** — "Cuadrilla A", cuatro miembros, un foreman.

**Borde** — Un trabajador que pasa de la cuadrilla A a la B a mitad de mes. Su
`to_date` en A y su `from_date` en B son consecutivos, y los timesheets de cada
período se atribuyen correctamente sin tocar registros viejos.
