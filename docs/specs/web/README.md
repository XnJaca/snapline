---
id: SPECS-WEB-INDEX
title: "Specs Web — Índice"
type: index
tags:
  - index
  - spec
  - web
---

# Specs — API / Angular admin / sitio público

Features de `api/`, `web/` y del sitio público en Astro.

## Convención

Cada spec vive en `NNNN-slug/README.md`, numeración secuencial.

## Índice

Se genera solo desde el frontmatter — no hay tabla que mantener a mano.

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], file.folder)) AS "Spec",
  status AS "Estado",
  goal AS "Goal",
  apps AS "App(s)",
  frente AS "Frente",
  updated AS "Actualizado"
FROM "specs/web"
WHERE type = "spec"
SORT file.folder ASC
```

Por estado, para ver qué está en vuelo:

```dataview
TABLE WITHOUT ID
  status AS "Estado",
  length(rows) AS "Cuántos",
  join(sort(rows.file.folder), ", ") AS "Specs"
FROM "specs/web"
WHERE type = "spec"
GROUP BY status
SORT status ASC
```

> Las tablas renderizan **en Obsidian**. En GitHub se ven como bloques de código;
> ahí el índice es la lista de carpetas, que ya está numerada.

**Un spec sin `type: spec` en el frontmatter no aparece acá.** `/spec-new` lo pone
siempre; si creaste uno a mano y no lo ves, es eso.

El kanban vive en [[BOARD-specs-web|BOARD — Specs Web]].
