---
id: DOM-<slug>
title: "Nombre del Agregado"
type: domain
status: borrador
related_specs: []
related_adrs: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - domain
  - domain/borrador
---

# Nombre del Agregado

> **Meta**
> - Parte de: [[README|Modelo de dominio]]

## Qué es

Definición en una frase. Sin adjetivos de relleno.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|----------|------|-------------|-------|
| _ejemplo_ | string | sí | _descripción_ |

## Invariantes

Reglas que SIEMPRE deben cumplirse. Si una regla no siempre aplica, no es invariante.

- _regla 1_

## Comportamiento offline

Si este agregado se crea o modifica desde el móvil: qué se genera en el dispositivo,
cómo se resuelve un conflicto de sincronización, y si el conflicto lo resuelve el
sistema o un humano.

## Eventos que emite

- `AgregadoCreado`

## Relaciones con otros agregados

- [[otro-agregado]] — qué relación

## Qué NO es

Límites del agregado. Qué responsabilidades no asume.

- _no es responsable de..._

## Ejemplos

### Ejemplo 1 — caso típico
### Ejemplo 2 — caso borde

## Specs que tocan este agregado

- [[NNNN-spec-nombre]]

## ADRs relevantes

- [[NNNN-adr-nombre]]
