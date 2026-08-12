---
id: DEBT-0005
title: "El photo release se quita, y está en cuatro lugares"
aliases:
  - "DEBT-0005: El photo release se quita, y está en cuatro lugares"
type: tech-debt
status: resuelta
severity: alta
origin: "SPEC-0007"
apps:
  - api
  - mobile
trigger: "Antes de implementar el spec de publicación, o antes de la primera foto que William quiera publicar de verdad"
created: 2026-08-10
updated: 2026-08-12
tags:
  - tech-debt
  - tech-debt/resuelta
  - publicacion
---

# DEBT-0005: El photo release se quita, y está en cuatro lugares

## Contexto

Decidido el 2026-08-10, probando SPEC-0007: **el gate del photo release sale del
producto.**

El razonamiento de quien decide: el contratista está autorizado a fotografiar la obra
en la que trabaja, la decisión de publicar es suya y no del cliente, y **no hay dónde
subir un permiso firmado** — ni pantalla, ni flujo, ni intención de construirlos.

Se dejó constancia del contraargumento y se decidió igual, que es lo que corresponde:

> El gate no bloquea tomar fotos ni mostrárselas al cliente — solo `visibility =
> PUBLIC`. Lo que evita es que la casa de alguien termine en Instagram sin que nadie
> lo haya pensado. Sacarlo elimina esa red, y el problema que produce se descubre
> tarde: con la foto ya publicada y un cliente enojado.

[[../DECISIONES]] tenía una salida intermedia anotada —*"photo release del cliente
como cláusula del estimado"*— que también queda descartada por esta decisión.

## Qué hay que hacer, y por qué no es una casilla

El gate **no vive en una pantalla**. Está en cuatro lugares y sacarlo cruza dos apps:

| Dónde | Qué hay |
|---|---|
| Base de datos | Trigger que rechaza `PUBLIC` sin `photo_release_granted_at`. Migración propia |
| [[../domain/cliente\|cliente]] | El invariante, `photo_release_document_id`, y *"revocar despublica"* |
| [[../domain/contenido\|contenido]] | La escalera de visibilidad se apoya en él |
| Regla 17 del `CLAUDE.md` | Es una **regla dura**: se reescribe o se elimina, con su fecha |
| [[../adr/0011-envelope-de-errores/README\|ADR-0011]] | Usa `PHOTO_RELEASE_REQUIRED` como ejemplo de código de error |

Además, `apps/mobile` muestra hoy el estado en la ficha del cliente
(`customerPhotoReleaseGranted` / `Missing` / `Help`), con sus claves en `en` y `es`.

**Va con entrada propia en `DECISIONES.md`**, explicando el porqué. Sin eso, dentro de
seis meses alguien lo repone por costumbre al leer la ficha de dominio.

## Por qué es severidad alta

No porque rompa algo hoy —hoy no publica nadie—, sino porque **cada semana que pasa
suma lugares que lo asumen**. El frente de publicación ya está construido en el API
contra este invariante; el spec de la galería de fotos lo va a asumir también. Cuanto
más tarde, más superficie que desarmar.

## Workaround actual

Ninguno hace falta: el gate no molesta hasta que alguien quiera publicar, y ese frente
todavía no tiene pantalla en el móvil.

## Trigger

- **Antes de implementar el spec de publicación**, que es el primero que choca de
  frente con esto.
- O **antes de la primera foto que William quiera publicar de verdad**, lo que llegue
  primero.

## Al empezar a resolverla — 2026-08-12

El `domain-guardian` revisó el modelo antes de tocarlo. **No eran cuatro lugares.**
Lo que la tabla de arriba no listaba:

| Dónde | Qué faltaba |
|---|---|
| `1786168800002-IndexesAndInvariants.ts` | **Dos** triggers con sus funciones: `media_asset_photo_release` y `published_project_release` |
| `1786168800000-InitialSchema.ts:298` | La FK `customer_release_doc_fk` hacia `media_asset` |
| `customers.controller.ts` · `.service.ts` | El endpoint `POST /customers/:id/photo-release` entero |
| `error-codes.ts` · `http-exception.filter.ts` · `error-envelope.spec.ts` | El código `PHOTO_RELEASE_REQUIRED`, su firma de trigger y el test que lo cubre |
| `requests/` | Dos requests de Bruno, uno de ellos en `edge-cases/` |
| [[../domain/publicacion\|publicación]] · [[../domain/proyecto\|proyecto]] · [[../domain/estimado\|estimado]] | Tres fichas más con el invariante o su cláusula |
| SPEC-0005 y SPEC-0006 | Dos specs **Implementados** con criterios `[x]` que lo afirman |
| `tables.dart` | La columna de Drift, que obliga a un `schemaVersion` nuevo |

Y dos hallazgos que no causa esta deuda pero que se cruzan con ella:

- **La escalera `INTERNAL → CLIENT → PUBLIC` no está aplicada en ningún lado.**
  `media.service.ts` deja saltar de `INTERNAL` a `PUBLIC` directo, hoy.
- **"Revocar despublica en cascada" nunca se implementó.** `setPhotoRelease` solo
  pone el campo en null. Sacar el gate lo resuelve: no queda nada que cascadear.

### Lo que se decidió al resolverla

- **El trigger no se va sin reemplazo.** Sacándolo tal cual, `PUBLIC` quedaba sin
  ningún invariante en la base y todo pasaba a depender de que ningún endpoint
  futuro se saltee la validación. En su lugar entra `enforce_exif_stripped`:
  `PUBLIC` exige `exif_stripped_at` en las fotos. El invariante ya estaba declarado
  en [[../domain/contenido|contenido]] y el camino feliz ya limpia solo, así que no
  cambia ningún comportamiento visible. La regla 17 se reescribió con eso,
  conservando su número.
- **La columna de Drift se dropea** en `schemaVersion` 5 con `TableMigration`, en
  vez de dejarla muerta. La justificación de "se agregan columnas, no se recrea la
  base" protege la bandeja de salida, y la bandeja vive en otra tabla.
- **`document_kind` conserva `PHOTO_RELEASE`.** Postgres no deja quitar un valor de
  un enum sin reconstruir el tipo; es una etiqueta inerte que ningún DTO asigna.
