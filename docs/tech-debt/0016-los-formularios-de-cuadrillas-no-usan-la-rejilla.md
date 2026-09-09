---
id: DEBT-0016
title: "Los formularios de Cuadrillas maquetan cada uno a su manera y no usan la rejilla del panel"
aliases:
  - "DEBT-0016: Los formularios de Cuadrillas maquetan cada uno a su manera y no usan la rejilla del panel"
type: tech-debt
status: resuelta
severity: baja
origin: "SPEC-0011"
apps:
  - web
trigger: "El próximo cambio a `styles/_form.scss` —un ancho de campo, un gap, el borde entre bloques— que las tres pantallas de la rejilla reciban y las de Cuadrillas no. También el sexto formulario que se agregue al panel: con cinco maquetas propias, copiar la de al lado ya es más fácil que usar la rejilla"
created: 2026-09-09
updated: 2026-09-09
tags:
  - tech-debt
  - tech-debt/resuelta
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

## Cómo se resolvió

El parcial ganó lo que le faltaba para servir adentro de un diálogo, y las cinco
pantallas —más `projects/customer-dialog`, que arrastraba el mismo envoltorio
copiado— pasaron a consumirlo.

**Lo que se agregó a `_form.scss`:**

- `dialog-air` — el `padding-block` que evita que Material recorte el label
  flotante del primer campo. Estaba escrito seis veces, con su comentario.
- `dialog-stack` — la columna de campos apilados, para el diálogo de dos o tres.
- `dialog-fields` — la rejilla adentro del diálogo, con su `container-type`.
- `widths-contained` — los mismos anchos `field--*`, preguntando por `@container`
  en vez de por `@media`. Los tres escalones de `widths` se extrajeron a mixins
  privados para que las dos variantes compartan los spans y no los repitan.

**El breakpoint tenía que mirar al contenedor**, y esa era la razón de fondo por
la que `member-dialog` no había usado la rejilla: un diálogo mide 40rem con el
navegador a 1920 y con el navegador a 1100, así que las media queries de `widths`
no dicen nada ahí. El comentario que lo explicaba ya estaba escrito en
`member-dialog.scss`; lo que faltaba era que viviera en el sistema.

**Pantalla por pantalla:**

| Pantalla | Qué pasó |
|---|---|
| `member-dialog` | Su `.pair` a mano pasó a `dialog-fields` + `widths-contained`; los cuatro campos del par son `field--long` y el resto `field--full` |
| `crew-dialog` | `dialog-stack` |
| `crew-member-dialog` | `dialog-stack` |
| `assign-dialog` | `dialog-stack`, y se borró un `.empty` que su plantilla no usa |
| `projects/customer-dialog` | `dialog-stack`, y se fue un `container-type` huérfano —`address-field` declara el suyo en su `:host`— |
| `customers/site-dialog` | `dialog-fields` + `widths-contained`; su `.extra` de dos columnas con su propio `@container` era `field--long` escrito a mano |

`site-dialog` no estaba en el inventario de esta ficha y es **el original del que
salió el patrón copiado**: el comentario que esta rama borró de `customer-dialog`
decía literalmente "mismo envoltorio que `site-dialog`". Resolver las cinco de
Cuadrillas y dejar afuera la que se había copiado habría sido cerrar la deuda por
la mitad. Lo encontró `code-reviewer`.

Los seis `.error` copiados —ocho líneas idénticas cada uno— pasaron a
`form.error`. Los cinco estaban **sin su `line-height` hermano**, que es el
defecto de la regla 22 que el mixin ya tenía resuelto; lo mismo en `.status`,
`.access__text`, `.colors__label` y `.colors__hint`.

`crew-dialog` no pasó a `fields` como decía esta ficha: sus tres campos ocupan la
fila entera —el capataz es condicional, así que emparejarlo con el nombre dejaría
un hueco cuando no hay candidatos— y una rejilla de doce columnas donde todo
ocupa doce es la misma columna con más maquinaria. Es el argumento que la ficha ya
usaba para los dos diálogos de dos campos.

`invite-dialog` tampoco: **no es un formulario**. No tiene campos ni el `grid`
propio que esta ficha le atribuía —lo que tiene es un `place-items: center` para
centrar el icono—; es una pantalla de resultado con el código como héroe. Lo único
que se le tocó fueron dos `line-height` literales que ahora salen de la escala.
Los que le quedan —el tamaño del código, el del icono y su tracking— son tamaños
fuera de la escala tipográfica, que la regla 22 no exceptúa: van a `DEBT-0017`,
porque cambiarlos es una decisión de diseño y no un reemplazo mecánico.

### La paleta de cuadrillas se queda fuera de los tokens

Confirmado, con el argumento que ya estaba escrito en `core/brand/crew-colors.ts`:
el color de una cuadrilla es un dato que elige el usuario y se pinta tal cual,
como el nombre. Lo que sí es decisión del sistema —qué seis opciones se ofrecen— es
justamente lo que hace que el archivo viva en `core/brand/` y no adentro del
componente, donde la regla 22 no lo distinguiría de un hex hardcodeado.
