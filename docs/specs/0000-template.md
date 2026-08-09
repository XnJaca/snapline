---
id: SPEC-NNNN
title: "Nombre de la feature"
aliases:
  - "SPEC-NNNN: Nombre de la feature"
type: spec
platform: web | mobile
status: borrador
goal: "Una sola frase: qué tiene que ser cierto cuando esto esté terminado."
apps: []
depends_on: []
domain: []
frente: administrativo | campo | cliente | reportes | publicidad
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - spec
  - spec/borrador
---

# SPEC-NNNN: Nombre de la feature

> **Meta**
> - Apps afectadas: `api` | `web` | `mobile` | `site`
> - Depende de: [[NNNN-otro-spec]]
> - Frente: ver [[vision]]
>
> _Estado, goal, tags y resto de metadata viven en el frontmatter arriba — no duplicar aquí._

---

## Goal

**Vive en el campo `goal` del frontmatter, no acá.** Una sola frase, en presente,
que describe qué es cierto cuando esto está terminado.

Es la frase contra la que el revisor de código valida lo implementado, así que
tiene que ser verificable leyendo código. Si el goal es "mejorar la experiencia",
el revisor no puede hacer su trabajo y el spec se rechaza.

| Mal | Bien |
|---|---|
| Mejorar la gestión de fotos | Una foto tomada sin señal se sube sola cuando vuelve la red, sin que el trabajador haga nada |
| Implementar facturación | William emite una factura desde un proyecto terminado y su total nunca cambia aunque cambie el catálogo |
| Agregar asistencia | El trabajador marca entrada en menos de tres toques y el sistema registra si estaba dentro de la obra |

## Problema

Qué problema real resuelve esto para qué usuario. Sin esta sección, rechazar el spec.

## Alcance

### Entra
- _qué SÍ hace esta feature_

### No entra
- _qué explícitamente NO hace — evita scope creep_

## Modelo de dominio afectado

Qué agregados toca. Enlaces de Obsidian:
- [[proyecto]]
- [[registro-de-tiempo]]

Si introduce un agregado nuevo, documentarlo primero con `/domain-new`.

## Comportamiento sin señal

Obligatorio en todo spec con `platform: mobile`. Qué pasa si el dispositivo no
tiene red al ejecutar esta acción: se encola, se degrada, o se bloquea (y por qué).

## Flujo de usuario

Pasos concretos. Diagrama si ayuda.

## Contrato de API

Endpoints nuevos o modificados. Request/response en ejemplos.

```http
POST /api/...
```

## UI

Wireframes o descripción de pantallas.

## Criterios de aceptación

- [ ] _qué tiene que ser verdad para considerar esto terminado_
- [ ] _tests que deben pasar_

## Riesgos / consideraciones

- _qué podría complicarse_

## ADRs relacionados

- [[NNNN-titulo-del-adr]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| YYYY-MM-DD | borrador | Creado |
