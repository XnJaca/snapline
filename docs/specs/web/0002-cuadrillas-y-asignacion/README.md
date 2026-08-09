---
id: SPEC-0002
title: "Cuadrillas y Asignación"
aliases:
  - "SPEC-0002: Cuadrillas y Asignación"
type: spec
platform: web
status: implementado
goal: "William sabe cuánta gente mandó a cada obra y en qué fecha, y puede compararlo contra quiénes marcaron asistencia."
apps: [api]
depends_on: []
domain: [cuadrilla, proyecto]
frente: administrativo
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/implementado
---

# SPEC-0002: Cuadrillas y Asignación

> **Spec retroactivo.** Se escribió después de implementar, contra la regla 2.

## Problema

Textual de William: *"no sé cuántos mandé a cada proyecto"*. Tiene dos cuadrillas
y la gente rota entre ellas, así que un reporte de marzo tiene que reflejar quién
estaba en marzo — no quién está hoy.

## Alcance

### Entra
- Cuadrillas con nombre, color y foreman
- Pertenencia **con rango de fechas**
- Asignación al proyecto por fecha, con `plannedHeadcount`
- Asignar cuadrilla completa o persona suelta

### No entra
- Turnos ni horarios: cuándo trabaja sale del registro de tiempo
- Roles o permisos por cuadrilla — el rol vive en la membresía
- Planificación de capacidad

## Modelo de dominio afectado

- [[cuadrilla]] · [[proyecto]] · [[usuario-y-membresia]]

## Contrato de API

```http
GET  /api/crews · POST /api/crews · PATCH /api/crews/:id
GET  /api/crews/:id/members · POST /api/crews/:id/members
POST /api/crews/:id/members/:memberId/end
POST /api/projects/:id/assignments
```

## Criterios de aceptación

- [x] Nadie puede estar en dos cuadrillas con fechas solapadas — constraint de
      exclusión en la base, no validación de formulario
- [x] La asignación acepta cuadrilla **o** persona, nunca ambas
- [x] La pertenencia histórica no se altera al mover a alguien de cuadrilla
- [x] **Un `WORKER` solo ve proyectos donde tiene asignación** — directa o por la
      cuadrilla a la que pertenecía en esa fecha. Pedir uno ajeno por id devuelve
      404, no 403: no se confirma que exista

## Riesgos / consideraciones

El solapamiento lo impide un `EXCLUDE USING gist` sobre `daterange`. Si esa
restricción se cae, los timesheets históricos empiezan a atribuir horas a la
cuadrilla equivocada sin que nada avise.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | implementado | Spec retroactivo sobre código ya en `main` |
