---
id: DEBT-0016
title: "Los formularios de Cuadrillas maquetan cada uno a su manera y no usan la rejilla del panel"
aliases:
  - "DEBT-0016: Los formularios de Cuadrillas maquetan cada uno a su manera y no usan la rejilla del panel"
type: tech-debt
status: abierta
severity: baja
origin: "SPEC-0011"
apps:
  - web
trigger: "El próximo cambio a `styles/_form.scss` —un ancho de campo, un gap, el borde entre bloques— que las tres pantallas de la rejilla reciban y las de Cuadrillas no. También el sexto formulario que se agregue al panel: con cinco maquetas propias, copiar la de al lado ya es más fácil que usar la rejilla"
created: 2026-09-09
updated: 2026-09-09
tags:
  - tech-debt
  - tech-debt/abierta
  - panel
---

# DEBT-0016: Los formularios de Cuadrillas maquetan cada uno a su manera y no usan la rejilla del panel

## Contexto

Es deuda **de cronología, no de criterio**. SPEC-0010 completó el sistema de
diseño y estrenó `apps/web/src/styles/_form.scss` —una rejilla de campos con sus
anchos declarados— pasando por ella a Clientes y Obras. SPEC-0011 entró después,
escrito antes de que ese archivo existiera, así que sus cinco diálogos resuelven
la maqueta cada uno por su cuenta.

`_form.scss` expone cinco mixins —`surface`, `block`, `block-title`, `fields`,
`widths`— y las clases `field--date | short | medium | long | full`. Hoy lo usan
tres pantallas:

```
customers/customer-form      projects/customer-dialog      projects/project-form
```

Y no lo usan estas cinco:

| Pantalla | Líneas | Cómo maqueta hoy |
|---|---|---|
| `crews/member-dialog` | 74 | `grid-template-columns: repeat(2, minmax(0, 1fr))` propio |
| `crews/invite-dialog` | 77 | mezcla `flex` con un `grid` propio |
| `crews/crew-dialog` | 62 | `flex` con los gaps puestos a mano |
| `crews/crew-member-dialog` | 26 | `flex`, dos campos apilados |
| `crews/assign-dialog` | 26 | `flex`, dos campos apilados |

**Los dos últimos probablemente no deban cambiar**: dos campos apilados es lo
correcto, y meterlos en una rejilla de doce columnas sería ceremonia. La deuda
real son los tres primeros, y `member-dialog` es el más claro — su rejilla de dos
columnas es una versión a mano de `fields`.

## Qué no se hizo

Nada de esto se ve roto: las cinco pantallas **ya consumen tokens**
—`--sl-space-*`, `--mat-sys-*`—, tienen cero hex literales y se verificaron en el
navegador en los dos temas. Lo que falta no es corregir valores, es reemplazar
cinco maquetas propias por los mixins que ya existen.

Queda además una decisión tomada por omisión y no explícitamente:
`core/brand/crew-colors.ts` es una paleta **fuera del sistema de tokens**, con el
argumento de que el color con el que William distingue una cuadrilla es dato de
dominio y no color de tema. `code-reviewer` lo aceptó con ese argumento. Conviene
confirmarlo o moverlo al pasar por acá, no dejarlo decidido por descuido.

## Workaround actual

Ninguno hace falta: las pantallas funcionan y se ven bien. El costo es de
mantenimiento, no de uso.

## Costo de resolverla

Chico y acotado al panel. Tres archivos de estilos y sus plantillas:

| Qué | Cambio |
|---|---|
| `crews/member-dialog` | La rejilla propia pasa a `@include form.fields` con `field--*` |
| `crews/invite-dialog` | Separar el bloque de campos del bloque del código, con `block` |
| `crews/crew-dialog` | `flex` con gaps a mano pasa a `fields` |
| `crew-colors.ts` | Confirmar que se queda fuera de los tokens, o moverlo |

Sin cambios de API, de contrato ni de dominio.

## Costo de NO resolverla

**El modo de fallo es que la rejilla deje de ser la rejilla.** Un ancho de campo
o un gap que se corrija en `_form.scss` va a llegar a tres pantallas y no a las
otras cinco, y la diferencia se va a ver como un descuido de diseño sin que nadie
sepa de dónde salió.

Y hay un efecto peor que la inconsistencia: **la maqueta propia se copia.** Con
cinco pantallas resolviéndolo a mano, el sexto formulario del panel se va a
escribir mirando al de al lado y no la rejilla, y ahí la deuda deja de ser de
cinco archivos.

## Trigger

El próximo cambio a `_form.scss` que las tres pantallas reciban y las cinco no.
O el sexto formulario del panel, que es cuando copiar la maqueta de al lado se
vuelve el camino fácil.
