---
id: DEBT-0017
title: "El diálogo del código de invitación fija tamaños fuera de la escala tipográfica"
aliases:
  - "DEBT-0017: El diálogo del código de invitación fija tamaños fuera de la escala tipográfica"
type: tech-debt
status: backlog
severity: baja
origin: "DEBT-0016"
apps:
  - web
trigger: "El segundo dato héroe del panel —un total de factura, un contador de obra— que necesite un tamaño más grande que `title` y no lo encuentre en la escala. También el primer cambio a la escala tipográfica en `design-tokens.json`, que este diálogo no va a recibir"
created: 2026-09-09
updated: 2026-09-09
tags:
  - tech-debt
  - tech-debt/backlog
  - panel
---

# DEBT-0017: El diálogo del código de invitación fija tamaños fuera de la escala tipográfica

## Contexto

Salió al pasar por `invite-dialog` resolviendo [[0016-los-formularios-de-cuadrillas-no-usan-la-rejilla|DEBT-0016]].
Esa ficha lo listaba como formulario y no lo es: no tiene campos, es una pantalla
de resultado con el código de seis dígitos como héroe. Los dos `line-height`
literales que tenía se cambiaron por sus tokens en esa misma rama; lo que queda es
de otra naturaleza.

## Qué no se hizo

En `apps/web/src/app/features/crews/invite-dialog/invite-dialog.scss`:

| Regla | Valor | Qué es |
|---|---|---|
| `.invite__code` | `font-size: 2.75rem` | El código, y **sin su `line-height` hermano** |
| `.invite__code` | `letter-spacing: 0.08em` | Lo que separa los pares de dígitos |
| `.invite__icon` | `width` / `height: 4.5rem` | El círculo del icono |
| `.invite__icon mat-icon` | `font-size: 2.25rem` | El icono adentro |
| `.invite__expires`, `__how`, `__hint` | `max-width: 34ch` | El ancho de lectura del texto de ayuda |

La escala llega hasta `--sl-font-size-display` (32px). El código mide 44px, que no
está en ningún lado.

## Workaround actual

Ninguno hace falta: el diálogo se ve como tiene que verse. Es la única pantalla
del panel con un dato a ese tamaño.

## Costo de resolverla

Depende de cuál de los dos caminos, y **esa es la decisión que falta**, no el
trabajo:

- **Bajar el código a `--sl-font-size-display`** (32px): una línea, y achica el
  héroe del diálogo un 27%. Es cambiar cómo se ve algo que ya se aprobó.
- **Agregar un rol a la escala** —un `hero` con su interlineado— en
  `design-tokens.json`, que es la fuente de las tres superficies (ADR-0009). Toca
  el sistema entero para un uso, y solo se justifica si hay un segundo.

El tracking y el `max-width` de lectura son el mismo tipo de pregunta: no hay
token de tracking ni de medida de línea en el sistema.

## Costo de NO resolverla

Bajo y acotado a esta pantalla. El modo de fallo es el de siempre con un literal:
si mañana la escala tipográfica se corrige, este diálogo no se entera. Y si
aparece un segundo dato héroe en el panel, se va a escribir mirando este archivo
—44px, 0.08em— en vez de la escala, que es como un literal se vuelve dos.

## Trigger

El segundo dato héroe del panel que necesite un tamaño mayor que `title`. Con dos
usos, agregar el rol a la escala deja de ser sobre-ingeniería y pasa a ser lo
barato.

## Propuesta de solución

Esperar al segundo uso. Cuando llegue, agregar el rol `hero` a
`design-tokens.json` con su `size` y su `leading` —los dos, que la mitad faltante
es justamente el error que la regla 22 documenta— y pasar las dos pantallas.

Si el segundo uso no llega, bajar el código a `display` y cerrar: un solo literal
no justifica un rol nuevo en la escala de tres superficies.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-09-09 | backlog | Registrada al resolver DEBT-0016 |
