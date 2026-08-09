---
id: ADR-0005
title: "Librería de i18n para el admin en Angular"
aliases:
  - "ADR-0005: Librería de i18n para el admin en Angular"
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

# ADR-0005: Librería de i18n para el admin en Angular

> Se decidió **antes** de escribir el primer componente de Angular: migrar de una
> opción a la otra con la app llena de claves es caro.

## Contexto

La internacionalización es obligatoria (regla 24) y el `locale` es **por usuario,
no por empresa**: William administra en inglés y es probable que su personal use
la app en español, dentro de la misma cuenta.

Hallazgo que condiciona la decisión, verificado en la documentación oficial de
Angular: el `$localize` nativo procesa cada mensaje **una sola vez**, cuando la
cadena se encuentra por primera vez. `loadTranslations()` en runtime no cambia lo
ya traducido. La documentación lo dice explícitamente: **no soporta cambio dinámico
de idioma sin recargar el navegador.**

## Decisión

**Transloco.** Aceptado el 2026-08-08.

Pesaron dos cosas concretas de este proyecto por sobre el mejor rendimiento del
nativo: los catálogos JSON se comparten con Flutter (ARB es JSON con metadata) y
con Astro sin convertir formatos, y el cambio de idioma sin recargar importa
porque **el `locale` es por usuario dentro de una misma cuenta** — William
administra en inglés mientras su gente usa la app en español.

## Alternativas consideradas

### Alternativa A — `@angular/localize` nativo

Un build por idioma (`ng build --localize`), sirviendo `/en/` y `/es/`. La
traducción queda inlineada en compilación, así que el rendimiento en runtime es el
mejor posible y no se agrega dependencia.

**Costo:** cambiar de idioma obliga a recargar o redirigir a otro bundle. El
formato es XLIFF, distinto del ARB de Flutter y del JSON del sitio en Astro, así
que las traducciones se mantienen por triplicado en tres formatos.

### Alternativa B — Transloco

Catálogos JSON cargados en runtime, cambio de idioma sin recargar, un solo build.

**Costo:** una dependencia más, y las traducciones viajan al cliente.

## Consecuencias

Si se acepta Transloco:

### Positivas

- Los catálogos JSON se comparten con Flutter (ARB es JSON con metadata) y con
  Astro, sin convertir formatos ni traducir tres veces.
- Cambio de idioma sin recargar, que importa porque el locale es por usuario.

### Negativas / Costos

- Dependencia de un paquete de terceros en una capa que atraviesa toda la UI.
- Peso adicional en el bundle.

### Riesgos

- Si el proyecto crece a muchos idiomas, cargar catálogos en runtime pesa más que
  inlinearlos. Con dos idiomas es irrelevante.

## Impacto en el modelo

Ninguno. Impacta `web/` y la convención de `code-guidelines/i18n.md`.

## Referencias

- `docs/code-guidelines/i18n.md`
- Documentación de Angular sobre `loadTranslations` y traducción en runtime.
