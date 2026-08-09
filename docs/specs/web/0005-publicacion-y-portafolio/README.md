---
id: SPEC-0005
title: "Publicación y Portafolio Público"
aliases:
  - "SPEC-0005: Publicación y Portafolio Público"
type: spec
platform: web
status: implementado
goal: "William publica una obra terminada a su web con un botón, y de ahí sale el material de redes ya identificado por proyecto y servicio."
apps: [api, site]
depends_on: []
domain: [publicacion, contenido, cliente]
frente: publicidad
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/implementado
---

# SPEC-0005: Publicación y Portafolio Público

> **Spec retroactivo.** Se escribió después de implementar, contra la regla 2.

## Problema

Es la premisa de venta del producto: la foto termina publicada. Hoy el material de
redes se pide por WhatsApp y llega sin identificar — una vez llegaron más de 200
fotos de golpe.

## Alcance

### Entra
- Publicar un proyecto con hero, galería, ciudad y testimonio
- Pares antes/después como pieza propia
- Feed de redes con lo ya usado marcado
- Portafolio público anónimo por slug de empresa, para el sitio en Astro

### No entra
- **Publicar en redes automáticamente.** Prepara y registra el material; postear
  lo hace una persona
- CMS: no se editan páginas arbitrarias
- Analítica del sitio

## Contrato de API

```http
POST /api/projects/:id/publish · POST /api/published/:id/unpublish
POST /api/projects/:id/before-after
GET  /api/social-feed · POST /api/social-posts
GET  /api/public/:companySlug/portfolio     ← anónimo
```

## Criterios de aceptación

- [x] Publicar exige que **todas** las fotos estén en `PUBLIC` y con EXIF limpio
- [x] El photo release del cliente lo verifica además un trigger de la base
- [x] Se despublica con `unpublished_at`, no se borra: el link ya está indexado
- [x] **Republicar conserva el slug** y vuelve a la misma URL
- [x] El portafolio público no filtra entre empresas

## Riesgos / consideraciones

El endpoint público es anónimo, así que no puede setear el contexto de tenant y
RLS le devolvería cero filas. Va por `public_portfolio()`, una función
`SECURITY DEFINER` que **solo expone lo que alguien publicó a propósito**.

Las imágenes se firman por 24 h porque el sitio es estático y regenera los links
en cada build. Si el portafolio agarra tráfico real, la salida es un CDN — ver el
trigger en [[../../PENDIENTES]].

## ADRs relacionados

- [[../../adr/0010-backblaze-b2-para-fotos/README|ADR-0010]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | implementado | Spec retroactivo sobre código ya en `main` |
