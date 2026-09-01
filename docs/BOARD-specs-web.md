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

- [ ] [[0009-clientes-y-propiedades/README|SPEC-0009 — Clientes y propiedades en el panel]] · el primer módulo que deja **escribir** desde el panel, y el primer eslabón de la cadena: sin cliente y propiedad no hay obra que crear, y sin obra no hay foto que publicar. El API está entero, así que es pantalla contra endpoints probados. Trae un invariante: **un cliente con obras, estimados o facturas no se borra**, con la comprobación en la base y no en el panel, porque hoy `remove()` no mira nada y la clave foránea no lo atrapa — el borrado es suave y la fila sigue existiendo. Revisado por `domain-guardian` y `spec-reviewer`: el guardián encontró que las **propiedades** quedaban vivas y alcanzables al borrar al cliente, y se resolvió con cascada; el revisor, que el `goal` no cubría el borrado y que el criterio prometía un conteo que la 409 no puede dar


## ✅ Aprobado (listo para implementar)



## 🛠️ En implementación


## 🎉 Implementado

- [x] [[0008-sesion-y-shell/README|SPEC-0008 — Sesión y shell del panel]] · PR #33 mergeado. Cookie `httpOnly` con su camino propio en el API y `membership.token_version`, que es lo que hace que cerrar sesión invalide algo: el refresh es un JWT sin estado y antes «salir» solo significaba que el navegador borró su copia. El claim ausente cuenta como 0, o el deploy expulsaba a toda sesión viva del móvil. La navegación sale de `membership.permissions[]`, sin replicar la tabla de roles. **El alcance del contenido creció a conciencia**: los ocho ejes leen los endpoints que ya existían, con carga, error y vacío; escribir sigue afuera. Cerró DEBT-0009 con `MatIconRegistry` y abrió DEBT-0010. 53 e2e contra Postgres, 80 unitarios del API y 33 del panel. **Dos correcciones al spec y tres bugs que solo se vieron en el navegador**

- [x] [[0007-cimientos-visuales/README|SPEC-0007 — Cimientos visuales del panel]] · PR #29 mergeado. Angular 22 + Material con los tokens por `theme-overrides`, `packages/tokens` generando SCSS y Dart, los dos temas y los dos idiomas. 10 tests. Cerró DEBT-0001 con los 71 valores idénticos a los que estaban a mano, y trajo ADR-0013. Tres bugs salieron de probar en el navegador, no de los tests: los catálogos en la carpeta equivocada, `light-dark()` resolviendo por `color-scheme` y no por el atributo, y Material tiñendo de naranja los cinco niveles de superficie. **Queda pendiente el único criterio que pide mirar**: los mismos tokens lado a lado en el teléfono y en el navegador

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
