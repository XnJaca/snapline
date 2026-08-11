---
id: BOARD-tech-debt
title: Board — Deuda técnica
type: board
tags:
  - board
  - kanban
  - tech-debt
kanban-plugin: board

---

## 📥 Backlog (registrada, sin trigger disparado)

- [ ] [[tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001: Los tokens se traducen a Dart a mano]] (trigger: scaffold de `apps/web`)
- [ ] [[tech-debt/0004-radio-de-geocerca-hardcodeado|DEBT-0004: El radio de geocerca por default es una constante, no un ajuste de la empresa]] (trigger: la segunda empresa, o el primer ajuste de radio que pida William)


## 🔥 Activa (causando fricción hoy)


## 🛠️ En resolución


## ✅ Resuelta

- [x] [[tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002: El login elige la membresía sin criterio de orden]] — `ORDER BY m.id` explícito y `memberships[]` en la respuesta. Queda abierto en otro nivel: no hay endpoint para cambiar de empresa sin re-login.
- [x] [[tech-debt/0003-telefono-sin-normalizar|DEBT-0003: El teléfono se compara sin normalizar]] — normaliza a E.164 **al leer**. Pendiente declarado: normalizar al escribir y migrar lo existente antes de cargar trabajadores reales.


## 🗑️ Descartada


%% kanban:settings
```
{"kanban-plugin":"board","show-checkboxes":true}
```
%%
