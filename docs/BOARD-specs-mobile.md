---
id: BOARD-specs-mobile
title: Board — Specs mobile
type: board
tags:
  - board
  - kanban
  - mobile
kanban-plugin: board

---

## 📝 Backlog (sin empezar)


## ✏️ Borrador (escribiendo el spec)

- [ ] [[specs/mobile/0002-idioma-de-la-app/README|SPEC-0002: Idioma de la app]]
- [ ] [[specs/mobile/0009-la-obra-como-lugar/README|SPEC-0009: La obra como lugar, no como botón]] — reorganiza la UI de SPEC-0008 sin tocar su lógica; salió de probarlo en el teléfono


## 🔍 Review (listo para revisar)


## ✅ Aprobado (listo para implementar)


## 🛠️ En implementación



## 🎉 Implementado

- [x] [[specs/mobile/0004-capa-local-y-sincronizacion/README|SPEC-0004: Capa local y sincronización]] — cerró con la tanda 2 de SPEC-0008: los dos criterios de `CONFLICT` verificados observando streams
- [x] [[specs/mobile/0001-login-movil/README|SPEC-0001: Login en la app móvil]] — 67 tests, revisado con `code-reviewer`
- [x] [[specs/mobile/0003-arquitectura-de-navegacion/README|SPEC-0003: Arquitectura de navegación]] — 104 tests + 9 de integración, PR #1 mergeado
- [x] [[specs/mobile/0005-proyectos-en-el-movil/README|SPEC-0005: Proyectos en el móvil]] — 226 tests + 2 de integración, PR #7 mergeado; trajo la escalera de estados al API
- [x] [[specs/mobile/0006-clientes-en-el-movil/README|SPEC-0006: Clientes en el móvil]] — 170 tests + 2 de integración, PR #4 mergeado; trajo `site.update` al API
- [x] [[specs/mobile/0008-asistencia-en-el-movil/README|SPEC-0008: Asistencia en el móvil]] — 266 tests, cinco PRs; la escalera de evidencia completa, los conflictos de SPEC-0004 cerrados y la foto subiendo a Backblaze
- [x] [[specs/mobile/0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007: Ubicación de la propiedad en el mapa]] — 239 tests en la suite, PR #12 mergeado; trajo Google Maps (ADR-0012), el bundle `com.snapline.app` y dos fixes de sincronización de SPEC-0004 con sus tests de regresión


## 🚧 Bloqueado


%% kanban:settings
```
{"kanban-plugin":"board","show-checkboxes":true}
```
%%
