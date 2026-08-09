---
id: ADR-0002
title: "Flutter para móvil, Angular para el admin, Astro para el sitio público"
aliases:
  - "ADR-0002: Flutter para móvil, Angular para el admin, Astro para el sitio público"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
---

# ADR-0002: Flutter para móvil, Angular para el admin, Astro para el sitio público

## Contexto

La app tiene que usarse en móvil y en web, siempre mobile-first. Eso admite varias
topologías, y elegir mal significa construir el mismo CRUD dos veces o quedarse sin
SEO en el frente que trae los leads.

Tres superficies con usuarios y contextos distintos: el trabajador parado en un
techo, la persona de oficina con tablas densas y reportes, y el desconocido que
busca un contratista en Google.

## Decisión

Tres superficies, un solo API en Nest:

| Superficie | Stack | Usuario |
|---|---|---|
| `mobile/` | Flutter (iOS + Android) | Trabajador y foreman en obra |
| `web/` | Angular | William y la persona administrativa |
| Sitio público | Astro consumiendo el mismo API | Quien busca un contratista |

## Alternativas consideradas

### Alternativa A — Flutter para todo, incluida la web

Un solo código para las tres superficies.

**Por qué no:** Flutter Web no indexa en buscadores. El sitio público es el frente
de publicidad, que es la premisa de venta del producto — dejarlo sin SEO contradice
la razón de existir de la app. Además, las tablas densas de reportes y facturación
se sienten peor en Flutter Web que en HTML nativo.

### Alternativa B — Flutter para móvil y web de la app, Astro solo para el sitio

Evita Angular manteniendo una sola base para la app.

**Por qué no:** el mismo problema de tablas densas, y no ahorra tanto como parece:
el admin y el móvil tienen flujos distintos, no son la misma UI en dos tamaños.

## Consecuencias

### Positivas

- Cada superficie usa la tecnología adecuada a su usuario y contexto.
- El sitio público mantiene SEO, que es donde se mide el ciclo.
- Un solo backend sirve a las tres: no se construye el mismo CRUD dos veces, y lo
  que paga William financia el núcleo del producto en vez de un panel desechable.

### Negativas / Costos

- Dos bases de código de UI que mantener, con dos capas de i18n y dos sistemas de
  tema que hay que mantener alineados.
- Los tokens de diseño tienen que definirse una vez y traducirse a CSS y a
  `ThemeData`. Ver `code-guidelines/estilos-y-temas.md`.

### Riesgos

- Deriva visual entre Angular y Flutter. Mitigación: los tokens son la fuente de
  verdad y ninguna superficie define valores propios.

## Impacto en el modelo

Ninguno directo. Condiciona el contrato del API, que debe servir a los tres
consumidores sin favorecer a uno.

## Referencias

- Reunión con William del 2026-08-08.
- Las cuentas de App Store y Google Play ya están disponibles, lo que descarta el
  argumento del PWA.
