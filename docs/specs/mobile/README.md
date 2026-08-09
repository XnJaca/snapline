---
id: SPECS-MOBILE-INDEX
title: "Specs Mobile — Índice"
type: index
tags:
  - index
  - spec
  - mobile
---

# Specs — Flutter móvil

Features de `mobile/`. Todo spec de esta carpeta declara su **comportamiento sin señal**.

## Índice

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], file.folder)) AS "Spec",
  status AS "Estado",
  goal AS "Goal",
  frente AS "Frente",
  updated AS "Actualizado"
FROM "specs/mobile"
WHERE type = "spec"
SORT file.folder ASC
```

```dataview
TABLE WITHOUT ID
  status AS "Estado",
  length(rows) AS "Cuántos",
  join(sort(rows.file.folder), ", ") AS "Specs"
FROM "specs/mobile"
WHERE type = "spec"
GROUP BY status
SORT status ASC
```

El kanban vive en [[BOARD-specs-mobile|BOARD — Specs Mobile]].
