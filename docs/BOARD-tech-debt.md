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

- [ ] [[tech-debt/0006-razon-de-anulacion-se-descarta|DEBT-0006: La razón de anular una factura se exige y se tira]] — **severidad media**: el DTO la pide obligatoria, el servicio la descarta y no hay columna donde guardarla (trigger: la primera factura real, o el spec retroactivo de billing)


## 🛠️ En resolución

- [ ] [[tech-debt/0005-photo-release-se-quita|DEBT-0005: El photo release se quita, y está en cuatro lugares]] — **severidad alta**: eran once lugares, no cuatro. En su lugar entra un trigger de EXIF, para que `PUBLIC` no quede sin invariante en la base


## ✅ Resuelta

- [x] [[tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002: El login elige la membresía sin criterio de orden]] — `ORDER BY m.id` explícito y `memberships[]` en la respuesta. Queda abierto en otro nivel: no hay endpoint para cambiar de empresa sin re-login.
- [x] [[tech-debt/0003-telefono-sin-normalizar|DEBT-0003: El teléfono se compara sin normalizar]] — normaliza a E.164 **al leer**. Pendiente declarado: normalizar al escribir y migrar lo existente antes de cargar trabajadores reales.


## 🗑️ Descartada


%% kanban:settings
```
{"kanban-plugin":"board","show-checkboxes":true}
```
%%
