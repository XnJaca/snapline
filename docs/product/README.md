---
id: PRODUCT-INDEX
title: "Producto — Índice"
type: index
tags:
  - index
  - product
---

# Producto

El porqué y el qué. Lo que decide si una idea entra antes de que exista un spec.

| Documento | Qué contiene |
|---|---|
| [[vision]] | Tesis, el ciclo, los cinco frentes, **"Qué NO somos"**, evidencia y supuestos |
| [[roadmap]] | Orden de construcción por fases y la tabla de descartados |
| `brief.md` | Brief comercial: precios, modelo de negocio, riesgos de sociedad |

## El gate

**La sección "Qué NO somos" de [[vision]] es el único gate duro de alcance.** Una
idea que la contradiga no entra sin modificar ese documento primero.

Para contrastar una idea sin abrir nada: `/scope-check <idea>`.

## Sobre `brief.md`

**Documento interno. Está fuera de git a propósito** — ver `.gitignore`. Contiene
estrategia de precios y notas explícitamente marcadas como "no compartir con
William". Si algún día tiene que versionarse, es una decisión consciente, no un
`git add .` distraído.

Lo que de ahí sí es público para el equipo — evidencia validada, refutada y
supuestos abiertos — está resumido en [[vision#Evidencia y supuestos]].
