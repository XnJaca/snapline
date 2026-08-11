---
id: DEBT-0004
title: "El radio de geocerca por default es una constante, no un ajuste de la empresa"
aliases:
  - "DEBT-0004: El radio de geocerca por default es una constante, no un ajuste de la empresa"
type: tech-debt
status: abierta
severity: media
origin: "SPEC-0007"
apps:
  - api
trigger: "La segunda empresa, o el primer ajuste de radio que William pida después de ver las banderas en obras reales"
created: 2026-08-10
updated: 2026-08-10
tags:
  - tech-debt
  - tech-debt/abierta
  - asistencia
---

# DEBT-0004: El radio de geocerca por default es una constante, no un ajuste de la empresa

## Contexto

Encontrado por el `spec-reviewer` al revisar
[[../specs/mobile/0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]], que
repetía la afirmación de la ficha de dominio sin verificarla contra el código.

[[../domain/empresa|La ficha de empresa]] declara `settings` como `jsonb` y dice qué
guarda: **"Radio de geocerca por default, método de asistencia"**. Y
[[../domain/cliente|la ficha de cliente]] dice que un `geofence_radius_m` nulo en el
sitio **usa el default de la empresa**.

## Qué no se hizo

Ese default no sale de la empresa. Es una constante de módulo:

```ts
// apps/api/src/time-entries/time-entries.service.ts
const DEFAULT_GEOFENCE_M = 150;
...
const radius = site.geofenceRadiusM ?? DEFAULT_GEOFENCE_M;
```

`company.settings` existe como columna y como campo de la entity, y **nadie lo lee**.
Dos fichas del dominio describen un comportamiento que el código no tiene.

## Por qué se posterga

No rompe nada hoy: hay una sola empresa y 150 metros es un default razonable para
obra residencial. Cablearlo a `settings` ahora significa decidir la forma de ese
`jsonb` —que hoy está vacío y sin esquema— sin ningún caso real que la guíe.

Y hay un orden natural: **el número correcto se descubre usando la app**, no
diseñando. SPEC-0007 ya lo anota como riesgo: *"muy chico y todos aparecen fuera de
la obra, muy grande y la geocerca no dice nada; conviene mirar con William qué radio
tiene sentido en sus obras"*. Recién ahí se sabe si el default de empresa hace falta o
si alcanza con fijarlo por sitio.

## Workaround actual

Cada propiedad puede fijar su propio `geofence_radius_m` desde SPEC-0007, y ese valor
sí se respeta. La constante solo aplica a las propiedades que lo dejan nulo.

## Trigger

- **La segunda empresa**, que casi seguro no trabaja con el mismo radio.
- O **el primer ajuste que William pida** después de ver banderas de "fuera de la
  obra" en obras reales: si pide moverlo para todas sus propiedades a la vez, el
  default de empresa dejó de ser opcional.

## Qué hay que hacer

- Definir el esquema de `company.settings` —hoy es `Record<string, unknown>` sin
  forma— o sacar el radio a su propia columna, que es más barato de validar.
- Leerlo en `evaluateGeofence` con la constante como último recurso.
- Y **alinear las dos fichas de dominio con lo que quede**, que es lo que originó
  esta deuda: describían un comportamiento que nunca existió.
