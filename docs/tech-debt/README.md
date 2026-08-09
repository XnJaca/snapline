---
id: DEBT-INDEX
title: "Deuda técnica — Índice"
type: index
tags:
  - index
  - tech-debt
---

# Deuda técnica

Decisiones **conscientes** de postergar algo. No es un basurero de TODOs.

Crear con `/debt-new <título>`.

| Sí es deuda | No es deuda |
|---|---|
| Endpoint sin UI, atajo arquitectónico, caso borde sin cubrir | Bugs (son tickets) |
| Librería sin migrar que ya duele | Features del roadmap (van a `specs/`) |
| Validación que hoy se hace a mano | TODOs locales de implementación (viven en el código) |

## Índice

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], title)) AS "Deuda",
  severity AS "Severidad",
  status AS "Estado",
  trigger AS "Trigger",
  updated AS "Actualizado"
FROM "tech-debt"
WHERE type = "tech-debt"
SORT status ASC, severity DESC
```

Toda deuda necesita **trigger**: el evento concreto que la despierta. Sin trigger,
queda olvidada para siempre — y eso es exactamente lo que esta carpeta existe para evitar.
