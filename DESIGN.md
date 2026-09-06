---
name: Snapline
description: Panel de gestión para el contratista sin oficina, del parte de obra a la foto publicada
colors:
  primary: "#C2410C"
  on-primary: "#FFFFFF"
  primary-container: "#FFEDD5"
  on-primary-container: "#7C2D12"
  surface: "#FFFFFF"
  on-surface: "#171717"
  on-surface-variant: "#525252"
  background: "#F4F4F5"
  outline: "#E5E5E5"
  outline-variant: "#E5E5E5"
  error: "#DC2626"
  error-container: "#FEE2E2"
  on-error-container: "#7F1D1D"
  warning: "#A16207"
  warning-container: "#FEF9C3"
  on-warning-container: "#713F12"
  success: "#15803D"
  success-container: "#DCFCE7"
  on-success-container: "#14532D"
  dark-primary: "#FB923C"
  dark-surface: "#171717"
  dark-on-surface: "#FAFAFA"
  dark-on-surface-variant: "#A3A3A3"
  dark-background: "#0A0A0A"
  dark-outline: "#404040"
typography:
  display:
    fontFamily: "BricolageGrotesque, Inter, system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: "normal"
  title:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "normal"
  body:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  caption:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "normal"
rounded:
  md: "8px"
  full: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  surface-block:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: "24px"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    height: "52px"
    padding: "0 24px"
  field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    height: "64px"
  field-in-header:
    height: "40px"
    rounded: "{rounded.md}"
  chip-status:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    rounded: "{rounded.md}"
    typography: "{typography.caption}"
---

# Snapline

## Overview

Panel de escritorio para un contratista de dos cuadrillas. **Herramienta de
trabajo: sobria, rápida, sin adornos** — densa a propósito, porque ver mucho de un
vistazo vale más que respirar. La referencia es Linear o Height.

El sistema se genera desde `design-tokens.json` en la raíz y sale a SCSS para el
panel y a Dart para el móvil (`pnpm tokens:generate`). **Los valores de este
archivo son un espejo, no la fuente**: si divergen, manda `design-tokens.json`.

Material recibe los tokens por `mat.theme-overrides()` en vez de derivar su propia
paleta desde una semilla. Por eso las claves llevan nombres de M3 y no propios: es
el espejo en web de prohibir `fromSeed` en Flutter. Ver ADR-0009 y ADR-0013.

Lo que este producto **no** debe parecer: QuickBooks, Procore/CompanyCam, SaaS de
plantilla, app consumer. Ver `PRODUCT.md`.

## Colors

Naranja quemado sobre neutros fríos. El acento sale de la construcción sin caer en
el amarillo de casco ni en el azul corporativo del software del rubro.

| Rol | Claro | Oscuro |
|---|---|---|
| Acción primaria | `#C2410C` | `#FB923C` |
| Superficie | `#FFFFFF` | `#171717` |
| Fondo | `#F4F4F5` | `#0A0A0A` |
| Texto | `#171717` | `#FAFAFA` |
| Texto secundario | `#525252` | `#A3A3A3` |
| Borde | `#E5E5E5` | `#404040` |

**Los dos temas se definen juntos.** El oscuro no se infiere del claro: el mismo
producto se usa en un techo con sol directo y en un sótano sin luz.

**La regla que hay que saber antes de usar estos colores:** naranja, ámbar y rojo
viven en 35 grados de rueda, así que **el tono no alcanza para distinguirlos**.

- El **naranja saturado es solo de la acción primaria**. Un botón sólido por
  pantalla. Si dos cosas son naranjas, ninguna es la acción.
- Los **estados van siempre en su variante `container`** — fondo tenue, texto
  oscuro, icono — nunca en relleno sólido.
- **Ningún estado se comunica solo con color.** El icono es obligatorio.

Contraste AA como piso, medido por tema. Un `#E5E5E5` sobre `#FFFFFF` sirve de
borde, nunca de icono ni de texto.

## Typography

Dos familias, con roles separados que no se cruzan:

- **Bricolage Grotesque** para la marca y el display. Solo ahí.
- **Inter** para todo lo demás: títulos, cuerpo, etiquetas, datos.

Escala corta a propósito — 13 / 16 / 20 / 32 — con la jerarquía cargada en el peso
(400 / 500 / 700) más que en el tamaño. En una pantalla densa, seis tamaños
compiten entre sí; tres pesos no.

El texto crece al traducir: ningún layout depende del largo de una cadena.

## Elevation

**Bordes, no sombras.** La separación la da `1px solid` en `outline` sobre un fondo
un escalón distinto. No hay escala de elevación y no hace falta: es una herramienta
de escritorio, no una pila de tarjetas flotantes.

Las sombras quedan para lo que de verdad flota sobre el resto — diálogos y menús —
y ahí las pone Material.

**Un solo radio: `8px`.** Botones, campos, tarjetas, tablas, diálogos, chips y
avisos. Lo único que no lo usa es lo que es un círculo por naturaleza — avatar,
botones de icono, el punto de una cuadrilla — con `999px`. Material trae un radio
distinto por componente y se pisa **una sola vez** en `styles.scss`, nunca
componente por componente.

## Components

**`sl-page`** es el armazón de toda pantalla: encabezado con icono, título, meta y
acciones, más los tres estados que una lista servida por red siempre tiene —
cargando, error con reintento, vacío. Ninguna pantalla los resuelve por su cuenta.

**Los controles del encabezado miden 40px.** Material trae los campos a 56 y los
botones a 40; en la misma fila se ven de dos tamaños. Se compacta una sola vez para
todo lo que esté dentro de `.page__header`. **Los formularios siguen a 64px**: ahí
la altura es lo que hace cómodo escribir.

**Todo contenido vive sobre una superficie** con borde, radio y fondo, a ancho
completo — nunca acotado con un `max-width` propio ni centrado a la fuerza. Los
campos adentro van en grilla de cuatro columnas, que baja a dos bajo 62rem y a una
bajo 34rem.

**Lo obligatorio se dice con palabras en el label** — `{campo} (obligatorio)` — no
con asterisco.

Tres archivos por componente, siempre: `.ts` + `.html` + `.scss`. Nunca `template:`
ni `styles:` inline.

## Do's and Don'ts

**Do**

- Consumir tokens: `var(--mat-sys-primary)`, `var(--sl-space-4)`.
- Definir los dos temas a la vez y verificar contraste en cada uno por separado.
- Acompañar todo estado con un icono, además del color.
- Alinear las zonas equivalentes entre elementos vecinos de una grilla: cuando una
  tarjeta tiene su línea divisoria más arriba que la de al lado, se lee como
  descuido.
- Poner la acción destructiva aparte del resto, y que pida confirmación nombrando
  lo que va a borrar.

**Don't**

- **Un hex literal en el archivo de un componente es un error de revisión.** Si
  falta un token, se agrega al sistema.
- No usar `--sl-radius-sm` ni `--sl-radius-lg` en el panel: existen porque el móvil
  los consume.
- No dejar nada apoyado sobre el fondo de la página.
- No usar el naranja saturado para nada que no sea la acción principal.
- No comunicar un estado solo con color.
- No escribir texto visible fuera de la capa de i18n, ni concatenar fechas, números
  o moneda a mano.
