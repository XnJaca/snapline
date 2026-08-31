---
id: DEBT-0009
title: "El panel no tiene sistema de iconos, solo SVG pegados a mano"
aliases:
  - "DEBT-0009: El panel no tiene sistema de iconos, solo SVG pegados a mano"
type: tech-debt
status: resuelta
severity: media
origin: "SPEC-0007"
apps:
  - web
trigger: "La primera pantalla del panel con navegación — SPEC-0008 ya la tiene — o el tercer icono nuevo, lo que llegue antes"
created: 2026-08-31
updated: 2026-08-31
tags:
  - tech-debt
  - tech-debt/resuelta
  - ui
---

# DEBT-0009: El panel no tiene sistema de iconos, solo SVG pegados a mano

## Contexto

`mat-icon` no dibuja nada por sí solo: necesita la fuente de Material Symbols, que
la app tiene que servir. Y ADR-0009 §7 no deja traerla de un CDN — las tipografías
van embebidas porque la app tiene que verse igual sin señal, y la misma lógica
aplica al panel aunque sea de oficina.

El paquete completo pesa **13 MB desempaquetado**: son todas las variantes
—outlined, rounded, sharp, con y sin relleno— de un set de miles de iconos, para
usar tres.

## Qué no se hizo

No se decidió cómo se sirven los iconos del panel. La pantalla de verificación de
tokens usa **SVG pegados directamente en el template**, con su `path` a mano.

Funciona para tres iconos de una pantalla de andamiaje. No escala: cada icono nuevo
es markup copiado, no hay forma de reusar uno, y nada garantiza que dos pantallas
usen el mismo dibujo para el mismo concepto.

## Workaround actual

SVG inline en `apps/web/src/app/features/dev-tokens/dev-tokens.html`, con la clase
`.status__icon` fijando tamaño y `fill: currentColor` para que tomen el color del
estado.

## Costo de resolverla

Tres caminos, ninguno evaluado todavía:

| Camino | Qué cuesta |
|---|---|
| Subset de la fuente | Un paso de build que extrae solo los iconos usados. El más liviano en runtime, el más frágil en el pipeline |
| `MatIconRegistry` con SVG propios | Cada icono es un archivo; se registran una vez y se usan con `<mat-icon svgIcon="...">`. Sin fuente, sin build extra |
| La fuente completa | Simple y pesado. Un panel de oficina lo aguanta mejor que un teléfono en una obra |

Sea cual sea, el móvil no se toca: Flutter trae Material Icons en su SDK.

## Trigger

**La primera pantalla del panel con navegación.** [[../specs/web/0008-sesion-y-shell/README|SPEC-0008]]
ya la trae —cada eje del shell lleva su icono— así que el disparador está a un spec
de distancia y conviene resolverlo antes de escribirla.

Un segundo disparador, si llega antes: el tercer icono nuevo pegado a mano. A esa
altura copiar el `path` deja de ser más barato que montar el sistema.

## Cómo se resolvió

**`MatIconRegistry` con SVG propios**, en
[[../specs/web/0008-sesion-y-shell/README|SPEC-0008]], que es donde el trigger se
disparó.

Doce archivos en `apps/web/public/icons/`, registrados una vez en
`core/icons/icons.ts` y usados con `<mat-icon svgIcon="projects">`. Los ocho ejes
del shell más `logout`, `language`, `theme` y `menu`.

Por qué este camino y no los otros dos:

- **La fuente completa** son 13 MB para doce dibujos, y el panel tendría que
  servirla entera porque ADR-0009 §7 no deja el CDN.
- **El subset** mete una herramienta más al build y un paso que se rompe callado:
  un icono nuevo que nadie agregó a la lista desaparece en producción y compila.
- **Los SVG propios** no necesitan nada: son archivos, los sirve la misma app, y
  cada icono pesa menos de 400 bytes. El precio es dibujarlos, que para un set de
  interfaz es una vez.

Los SVG llevan `fill="none"` en la raíz a propósito: `.mat-icon` declara
`fill: currentColor`, y sin ese atributo los trazos se rellenarían sólidos.

El móvil no se tocó: Flutter trae Material Icons en su SDK.
