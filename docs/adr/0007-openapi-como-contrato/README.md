---
id: ADR-0007
title: "OpenAPI como fuente única del contrato, con clientes generados"
aliases:
  - "ADR-0007: OpenAPI como fuente única del contrato, con clientes generados"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
---

# ADR-0007: OpenAPI como fuente única del contrato, con clientes generados

## Contexto

El API tiene tres consumidores: Angular, Astro y **Flutter**. Los dos primeros
pueden importar TypeScript; Flutter no.

En este producto el móvil es la superficie principal — el trabajador en el techo es
el usuario del que depende todo el ciclo. Un contrato en TypeScript dejaría
justamente a ese consumidor escribiendo sus modelos a mano, que es donde aparece la
deriva: el API cambia un campo, Angular se entera al compilar y Flutter se entera
en producción.

## Decisión

**`openapi.json` en la raíz del monorepo es la fuente única del contrato.** Lo emite
el API desde sus DTOs con el plugin de CLI de `@nestjs/swagger`, y de ahí se generan
los clientes:

```
apps/api (DTOs + class-validator)
        │  nest build + plugin de swagger
        ▼
   openapi.json          ← fuente única, versionada
        ├──▶ packages/contracts   (openapi-typescript)  → Angular, Astro
        └──▶ apps/mobile/lib/api  (openapi-generator)   → Flutter
```

`pnpm contracts:generate` desde la raíz regenera el spec y los tipos de TS.

## Alternativas consideradas

### Alternativa A — `packages/contracts` escrito a mano en TypeScript

Es el patrón de ACDEMIC y no necesita generadores.

**Por qué no:** Flutter queda fuera del contrato. Acá el móvil no es un consumidor
secundario, es el principal.

### Alternativa B — Contratos en TS **y** OpenAPI solo para Dart

Cubre a los tres, pero mantiene dos representaciones del mismo contrato que hay que
mantener alineadas a mano. Se resuelve el problema agregando el problema.

## Consecuencias

### Positivas

- Un cambio de campo en un DTO llega a los tres consumidores por el mismo camino.
- El plugin lee `class-validator`, así que los rangos y formatos viajan al contrato
  sin decorar nada: `lat` sale con `minimum: -90, maximum: 90`.
- El spec sirve además de documentación navegable en `/api/docs`.

### Negativas / Costos

- El contrato se **deriva** del código, no al revés. La regla 8 dice "contrato
  primero"; en la práctica eso significa diseñar el DTO antes que el controller,
  no escribir el spec a mano.
- `openapi.json` se versiona y hay que regenerarlo cuando cambia un DTO. Si se
  olvida, el diff del PR lo delata.
- Los `operationId` tienen que ser únicos en todo el spec — van prefijados con el
  controller. Sin eso los `list`/`get` de cada recurso colisionan y el generador
  produce tipos rotos.

### Riesgos

- **Que el spec quede desactualizado.** Mitigación: regenerarlo es parte de la
  definición de "endpoint terminado", y el `code-reviewer` lo verifica.
- Dependencia de que el plugin infiera bien. Cuando no alcance, se agrega
  `@ApiProperty()` en ese campo puntual, no en todos.

## Impacto en el modelo

Ninguno. Impacta `apps/api`, `packages/contracts` y `apps/mobile`.

## Referencias

- `packages/contracts/README.md`
- Estructura del monorepo: `pnpm-workspace.yaml`. Flutter vive en `apps/mobile`
  pero **fuera** del workspace de pnpm — no puede ser miembro.
