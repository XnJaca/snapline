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



## 🔍 Review (listo para revisar)



## ✅ Aprobado (listo para implementar)



## 🛠️ En implementación

- [ ] [[specs/mobile/0012-avance-de-la-obra/README|SPEC-0012: Avance de la obra]] — el hilo de la obra: hitos de estado, notas escritas, fotos y jornadas en un solo orden cronológico. Trae `project_status_change`, la tabla que hoy no existe, porque `project.status` guarda el ahora y pisa lo anterior. Revisado por `spec-reviewer`, que encontró dos bloqueantes: la ruta del endpoint que se retira estaba mal en las tres apariciones —es `/client-access`— y, el que importa, que una nota marcada para el cliente con fotos `INTERNAL` adjuntas **llegaba al portal sin sus fotos, en silencio**. De ahí salió que adjuntar eleve la escalera, y que cambiar `client_visibility_mode` entre al alcance: sin eso ninguna nota `CLIENT` sería visible jamás. Después `domain-guardian` encontró el agujero del modelo: **una obra creada después del despliegue no tenía hito de origen**, y el comportamiento sin señal se apoyaba justo en que siempre hubiera uno — lo escribe `create` ahora, y la señal que distingue un hito sembrado de uno real es invariante de la tabla y no una convención de la pantalla


## 🎉 Implementado

- [x] [[specs/mobile/0011-horas-de-la-obra/README|SPEC-0011: Horas de la obra]] — 92 tests en el API y 347 en el móvil, PR #32 mergeado; llenó la primera de las dos tabs placeholder de la obra. Trajo `decision_reason` al dominio, las dos operaciones de decisión al lote y **el turno de la bandeja**, que sale de un GRAVE: corregirse a uno mismo sin señal dejaba en el servidor la decisión descartada
- [x] [[specs/mobile/0010-fotos-de-la-obra/README|SPEC-0010: Fotos de la obra]] — 322 tests, PRs #25 y #26; trajo `POST /media/:id/tags` y la escalera de visibilidad aplicada al API. Dos tandas: la segunda salió entera de probar en el teléfono —etiquetar pasó a obligatorio y de a una, y apareció que volver la red no sincronizaba con la obra abierta— y dejó la regla de copy en `code-guidelines/i18n.md`
- [x] [[specs/mobile/0009-la-obra-como-lugar/README|SPEC-0009: La obra como lugar, no como botón]] — 269 tests, PR #20 mergeado; siete tandas de diseño probando en el teléfono, y de ahí salieron `SectionCard`, `StatusLine` y la regla de que el copy no fiscaliza
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
