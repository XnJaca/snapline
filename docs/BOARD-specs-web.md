---
id: BOARD-specs-web
title: Board — Specs web
type: board
tags:
  - board
  - kanban
  - web
kanban-plugin: board

---

## 📝 Backlog (sin empezar)


## ✏️ Borrador (escribiendo el spec)


## 🔍 Review (listo para revisar)


## ✅ Aprobado (listo para implementar)

- [ ] [[0008-sesion-y-shell/README|SPEC-0008 — Sesión y shell del panel]] · entrar, cerrar sesión de verdad, y a dónde navegar. Cookie httpOnly con su camino propio en el API, y la navegación desde los permisos que ya viajan en el login. Depende de SPEC-0007. Trae `membership.token_version`, revisado por `domain-guardian` — su hallazgo del claim ausente evitó que el deploy expulsara a todas las sesiones vivas



## 🛠️ En implementación

- [ ] [[0007-cimientos-visuales/README|SPEC-0007 — Cimientos visuales del panel]] · Angular 22 + Material, `packages/tokens` generando SCSS y Dart, los dos temas y los dos idiomas. 10 tests. Los 71 valores del `tokens.dart` generado salieron idénticos a los que estaban a mano. Falta `code-reviewer` y el PR


## 🎉 Implementado

- [x] [[0001-catalogo-de-servicios/README|SPEC-0001 — Catálogo de Servicios]] · ítems con costo, para ver margen. **Retroactivo**
- [x] [[0002-cuadrillas-y-asignacion/README|SPEC-0002 — Cuadrillas y Asignación]] · pertenencia con fechas, sin solapes. **Retroactivo**
- [x] [[0003-estimados-facturas-y-pagos/README|SPEC-0003 — Estimados, Facturas y Pagos]] · reemplazo de QuickBooks. Bloqueado para uso real hasta hablar con el contador. **Retroactivo**
- [x] [[0004-reportes-para-el-contador/README|SPEC-0004 — Reportes para el Contador]] · timesheet con tarifa congelada. **Retroactivo**
- [x] [[0005-publicacion-y-portafolio/README|SPEC-0005 — Publicación y Portafolio]] · publicar con un botón + feed público anónimo. **Retroactivo**
- [x] [[0006-portal-del-cliente/README|SPEC-0006 — Portal del Cliente]] · magic link, default en Etapas. **Retroactivo**


## 🚧 Bloqueado


%% kanban:settings
```
{"kanban-plugin":"board","show-checkboxes":true}
```
%%
