---
id: ADR-INDEX
title: "ADRs — Índice"
type: index
tags:
  - index
  - adr
---

# ADRs — Decisiones arquitectónicas

Una decisión que cuesta caro revertir se escribe acá antes de implementarse.
Stack, patrones de seguridad, estrategia de deploy, modelos de datos estructurales.

Crear con `/adr-new <título>`.

## Índice

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], file.folder)) AS "ADR",
  status AS "Estado",
  created AS "Creado",
  related_specs AS "Specs impactados"
FROM "adr"
WHERE type = "adr"
SORT file.folder ASC
```

## Qué es un ADR y qué no

| Es ADR | No es ADR |
|---|---|
| Elegir Postgres sobre Mongo | Nombrar una variable |
| Reemplazar QuickBooks en vez de integrarlo | Agregar un campo a un form |
| Cómo se verifica la asistencia | Qué color tiene el botón |

Si la decisión se puede revertir en una tarde, no es ADR.
