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

- [ ] [[tech-debt/0009-el-panel-no-tiene-iconos|DEBT-0009: El panel no tiene sistema de iconos, solo SVG pegados a mano]] — **severidad media**: `mat-icon` necesita una fuente que ADR-0009 §7 no deja traer de un CDN, y el paquete completo pesa 13 MB para usar tres iconos (trigger: la navegación de SPEC-0008, que ya lleva un icono por eje)


- [ ] [[tech-debt/0007-el-objeto-borrado-queda-en-el-bucket|DEBT-0007: Borrar una foto no libera el objeto en Backblaze]] — **severidad baja**: el borrado es suave para poder propagarlo, y el binario queda pagándose (trigger: cuando el almacenamiento se note en la factura, o la segunda empresa)

- [ ] [[tech-debt/0004-radio-de-geocerca-hardcodeado|DEBT-0004: El radio de geocerca por default es una constante, no un ajuste de la empresa]] (trigger: la segunda empresa, o el primer ajuste de radio que pida William)


## 🔥 Activa (causando fricción hoy)

- [ ] [[tech-debt/0006-razon-de-anulacion-se-descarta|DEBT-0006: La razón de anular una factura se exige y se tira]] — **severidad media**: el DTO la pide obligatoria, el servicio la descarta y no hay columna donde guardarla (trigger: la primera factura real, o el spec retroactivo de billing)


## 🛠️ En resolución

- [ ] [[tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001: Los tokens se traducen a Dart a mano]] — su trigger se disparó: `apps/web` es el segundo consumidor. `packages/tokens` genera el SCSS y el Dart desde `design-tokens.json`, y el `tokens.dart` generado salió con **los 71 valores idénticos** a los que estaban a mano. Pasa a Resuelta cuando el PR de SPEC-0007 se mergee


## ✅ Resuelta

- [x] [[tech-debt/0005-photo-release-se-quita|DEBT-0005: El photo release se quita, y está en cuatro lugares]] — PR #22 mergeado. Eran once lugares, no cuatro. En su lugar quedó `enforce_exif_stripped`, para que `PUBLIC` no se quedara sin invariante en la base. Queda anotado que la escalera `INTERNAL → CLIENT → PUBLIC` sigue sin aplicarse en orden

- [x] [[tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002: El login elige la membresía sin criterio de orden]] — `ORDER BY m.id` explícito y `memberships[]` en la respuesta. Queda abierto en otro nivel: no hay endpoint para cambiar de empresa sin re-login.
- [x] [[tech-debt/0003-telefono-sin-normalizar|DEBT-0003: El teléfono se compara sin normalizar]] — normaliza a E.164 **al leer**. Pendiente declarado: normalizar al escribir y migrar lo existente antes de cargar trabajadores reales.


## 🗑️ Descartada


%% kanban:settings
```
{"kanban-plugin":"board","show-checkboxes":true}
```
%%
