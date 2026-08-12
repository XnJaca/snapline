---
id: ADR-0011
title: "Envelope canónico de errores con código estable"
aliases:
  - "ADR-0011: Envelope canónico de errores con código estable"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-12
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
---

# ADR-0011: Envelope canónico de errores con código estable

## Contexto

Hasta hoy el API devolvía el error por defecto de Nest, con dos problemas medibles:

```
401 → {"message": "Falta el token", ...}
400 → {"message": ["displayName should not be empty", ...], ...}
```

1. **`message` cambia de tipo.** String en casi todos los casos, array cuando falla
   la validación. En un cliente tipado eso es `dynamic` o una unión escrita a mano.
2. **Ningún error está en el contrato.** El spec declaraba solo `200/201/204`, así
   que el cliente generado no tenía tipo de error: cada consumidor lo inventa.
3. **No hay forma de reaccionar a un error sin leer prosa en español.** Para
   distinguir "falta el photo release" de "falta limpiar el EXIF" —dos rechazos
   distintos del mismo endpoint, con acciones distintas— el cliente tendría que
   comparar strings. Y por la regla 24 esos mensajes se van a traducir, con lo cual
   la comparación se rompe el día que alguien use la app en inglés.

## Decisión

Un envelope único para toda respuesta de error:

```json
{
  "statusCode": 400,
  "code": "PHOTO_RELEASE_REQUIRED",
  "message": "El cliente no otorgó permiso para publicar sus fotos",
  "details": [{ "field": "displayName", "message": "no puede estar vacío" }],
  "path": "/api/media/019f.../visibility",
  "timestamp": "2026-08-08T21:14:02.310Z"
}
```

- **`code`** es el contrato de verdad: `SCREAMING_SNAKE`, estable, **nunca se
  traduce**. Es contra lo que el cliente ramifica.
- **`message`** es siempre `string`, para leer. Es lo que se traducirá.
- **`details`** es siempre un array —vacío cuando no aplica—, nunca metido dentro
  de `message`.
- `path` y `timestamp` para correlacionar con logs.

Los códigos viven en un enum del API y viajan al contrato, así que el cliente
generado los recibe como valores tipados y no como strings sueltos.

## Alternativas consideradas

### Alternativa A — Dejar el default de Nest y documentarlo

Cero trabajo de implementación.

**Por qué no:** no resuelve ninguno de los tres problemas. `message` seguiría
cambiando de tipo y el cliente seguiría ramificando sobre prosa traducible.

### Alternativa B — RFC 7807 (`application/problem+json`)

Es el estándar: `type`, `title`, `detail`, `instance`.

**Por qué no:** su campo de identificación es `type`, una URI que hay que hostear y
mantener. Para tres consumidores propios, un enum tipado en el contrato da la misma
garantía con menos ceremonia. Si algún día el API se abre a terceros, migrar a 7807
es mapear campos.

## Consecuencias

### Positivas

- El cliente ramifica sobre `code`, que no cambia al traducir ni al reescribir el
  mensaje.
- `message` y `details` tienen tipo fijo: se acabó el `dynamic`.
- Los errores entran al contrato, así que Dart y TypeScript los reciben generados.

### Negativas / Costos

- Cada `throw` nuevo debería declarar su `code`. Sin código explícito cae en uno
  genérico por status, que funciona pero no aporta.
- El catálogo de códigos es una superficie más que mantener alineada.

### Riesgos

- **Que se llene de códigos de un solo uso.** Mitigación: un código nace cuando el
  cliente necesita distinguirlo para *hacer algo distinto*; si solo se muestra el
  mensaje, alcanza el genérico.

## Impacto en el modelo

Ninguno. Impacta `apps/api/src/common/errors/` y a los tres consumidores.

## Nota posterior — 2026-08-12

`PHOTO_RELEASE_REQUIRED`, el código que este ADR usa de ejemplo, **se retiró del
catálogo** al sacar el gate de photo release (DEBT-0005). El ejemplo se conserva
tal como se escribió: es el caso que motivó la decisión —dos rechazos distintos del
mismo endpoint, con acciones distintas— y reescribirlo borraría el razonamiento. La
decisión de este ADR no cambia.

## Referencias

- Regla 8 (contrato) y regla 24 (i18n) del `CLAUDE.md` raíz.
