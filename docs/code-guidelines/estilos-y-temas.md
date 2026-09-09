---
id: GUIDE-estilos
title: "Estilos y temas"
type: guide
tags:
  - guide
  - ui
---

# Estilos y temas

Reglas 21, 22 y 23 del `CLAUDE.md` raíz, con el detalle de cómo se cumplen.

## 1. Tres archivos, siempre

Todo componente de Angular son tres archivos separados:

```
project-card/
├── project-card.component.ts      lógica
├── project-card.component.html    estructura
└── project-card.component.scss    estilos
```

```ts
// ✅
@Component({
  selector: 'sl-project-card',
  templateUrl: './project-card.component.html',
  styleUrls: ['./project-card.component.scss'],
})
export class ProjectCardComponent {}
```

```ts
// ❌ nunca — ni "porque es chiquito"
@Component({
  selector: 'sl-project-card',
  template: `<div class="card">{{ project.name }}</div>`,
  styles: [`.card { padding: 16px; background: #fff; }`],
})
```

**Por qué.** Un estilo dentro del `.ts` no se puede buscar con las herramientas de
CSS, no lo ve el linter de estilos, y no se puede extraer cuando el patrón se
repite en otros cinco componentes. En ACDEMIC esto se dejó pasar por componentes
chicos y hoy los estilos están desperdigados dentro de la lógica. El componente
chiquito es justamente el que crece.

Esto aplica también al archivo de test y al de i18n si los hubiera: un archivo,
una responsabilidad.

## 2. Tres capas de tokens

Los valores viven en **`design-tokens.json`** en la raíz del monorepo, que es la
fuente única para las tres superficies. Ver [[../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]].
Los snippets de abajo muestran la forma que toman en CSS; los hex salen de ahí.

El componente nunca ve un color. Ve un token semántico.

```
Primitivas          →   Semánticos           →   Componente
--sl-orange-700         --sl-color-primary       var(--sl-color-primary)
--sl-neutral-100        --sl-color-surface
--sl-space-4            --sl-color-danger
```

**Primitivas** — la paleta cruda. No se usan directamente en ningún componente.

Los neutros son de **gris puro** (`neutral`), sin tinte: `slate` tira a azul y hace
ver azuladas las fotos de obra; `stone` tira a cálido y en fondos oscuros se lee
como café. El calor lo pone el naranja, no los grises.

```scss
// styles/tokens/_primitives.scss
:root {
  --sl-orange-700:  #c2410c;
  --sl-neutral-050: #fafafa;
  --sl-neutral-900: #171717;
  --sl-neutral-950: #0a0a0a;

  --sl-space-1: 4px;
  --sl-space-2: 8px;
  --sl-space-3: 12px;
  --sl-space-4: 16px;

  --sl-radius-sm: 4px;
  --sl-radius-md: 8px;

  --sl-font-size-body: 16px;
  --sl-font-size-title: 20px;
}
```

**Semánticos** — qué significa cada color en la interfaz. Esta capa es la que cambia
entre tema claro y oscuro.

```scss
// styles/tokens/_semantic.scss
:root,
[data-theme='light'] {
  --sl-color-primary:            var(--sl-orange-700);
  --sl-color-primary-container:  #ffedd5;
  --sl-color-surface:            #ffffff;
  --sl-color-background:         var(--sl-neutral-050);
  --sl-color-text:               var(--sl-neutral-900);
  --sl-color-text-muted:         #525252;
  --sl-color-border:             #e5e5e5;
  --sl-color-danger:             #dc2626;
  --sl-color-danger-container:   #fee2e2;
  --sl-color-warning:            #a16207;   // banderas de asistencia
  --sl-color-warning-container:  #fef9c3;
  --sl-color-success:            #15803d;
  --sl-color-success-container:  #dcfce7;
}

[data-theme='dark'] {
  --sl-color-primary:            #fb923c;
  --sl-color-primary-container:  #7c2d12;
  --sl-color-surface:            #171717;
  --sl-color-background:         var(--sl-neutral-950);
  --sl-color-text:               #fafafa;
  --sl-color-text-muted:         #a3a3a3;
  --sl-color-border:             #404040;
  --sl-color-danger:             #f87171;
  --sl-color-danger-container:   #7f1d1d;
  --sl-color-warning:            #facc15;
  --sl-color-warning-container:  #713f12;
  --sl-color-success:            #4ade80;
  --sl-color-success-container:  #14532d;
}
```

### La regla que hace falta saber antes de usar estos tokens

Naranja, ámbar y rojo viven en 35 grados de rueda: **el tono no alcanza para
distinguirlos**. La separación la da la forma.

- El **naranja saturado es solo de la acción primaria**. Un botón sólido por
  pantalla. Si dos cosas son naranjas, ninguna es la acción.
- Los **estados van siempre en su variante `container`** —fondo tenue, texto
  oscuro, icono— nunca en relleno sólido.
- **Ningún estado se comunica solo con color.** El icono es obligatorio.

### Un solo radio

Todo lo que tiene esquinas usa **`--sl-radius-md`** (8px): botones, campos,
tarjetas, tablas, diálogos, chips, avisos y el menú. Lo único que no lo usa es lo
que es un **círculo** por naturaleza —avatar, botones de icono, el punto de color
de una cuadrilla, el icono del diálogo—, y eso lleva `--sl-radius-full`.

`--sl-radius-sm` y `--sl-radius-lg` existen en el JSON porque el móvil los
consume; **en el panel no se usan**. En Angular, Material trae un radio distinto
por componente —4px en los campos, píldora en los botones, 28px en los
diálogos— y eso se pisa una sola vez en `styles.scss`, con los tokens de forma
del sistema (`corner-*`), no componente por componente. La única excepción son
los botones con texto: Material los ata a `corner-full`, el mismo token que hace
círculo a los botones de icono, así que van con `mat.button-overrides` en el mismo
lugar. Se decidió el 2026-09-02 al ver un campo de 4px al lado de un botón en
píldora en la misma fila.

### El tamaño nunca viaja solo: siempre con su interlineado

**Toda regla que fija `font-size` fija su `line-height` hermano.** Los dos salen
de `design-tokens.json`, por rol:

```scss
.card__name {
  font-size: var(--sl-font-size-body);
  line-height: var(--sl-font-leading-body);
}
```

Cuanto más grande el texto, más chico el ratio: `caption` 1.45, `body` 1.5,
`title` 1.25, `display` 1.15. Un 1.5 a 32px abre huecos que parten el bloque.

Sin la mitad del interlineado, el tamaño **hereda el de Material** — un único 20px
para los cuatro tamaños de la escala. El título de 20px quedaba con ratio 1.00, y
nada de la pantalla se apoyaba en una retícula vertical. Se descubrió el
2026-09-04, midiendo por qué el panel "no tenía ritmo": `design-tokens.json` tenía
`size` y `weight` y ninguna entrada de interlineado.

**Un literal de `line-height` es el mismo error que un hex literal.** Si el valor
que hace falta no está en la escala, se agrega al sistema.

### La trampa del atajo de Material

`mat.theme-overrides()` pisa las **piezas** de un rol tipográfico —
`body-medium-size`, `-line-height`, `-tracking` — pero **Material emite además un
atajo compuesto**, `--mat-sys-body-medium`, y ese **no se recompone**. Quedan los
dos vivos y en desacuerdo:

```
--mat-sys-body-medium-size  →  16px          ← lo que pisamos
--mat-sys-body-medium       →  400 0.875rem / 1.25rem Inter   ← lo que sigue diciendo
```

Cualquier regla escrita como `font: var(--mat-sys-body-medium)` se lleva el valor
viejo. Era el caso del `body`, así que **todo el panel heredaba 14px**, un tamaño
que no está en la escala, mientras la variable de al lado decía 16.

**Consumir siempre las piezas, nunca el atajo:**

```scss
body {
  font-family: var(--mat-sys-body-medium-font);
  font-size: var(--mat-sys-body-medium-size);
  font-weight: var(--mat-sys-body-medium-weight);
  line-height: var(--mat-sys-body-medium-line-height);
  letter-spacing: var(--mat-sys-body-medium-tracking);
}
```

Lo mismo con el tracking: Material trae los valores de Roboto (+0.031em en el
cuerpo), y a Inter le quedan aguados. Se pisan a `normal` en el mismo bloque de
overrides, una sola vez.

### Nada flota: todo contenido vive sobre una superficie

**Ningún campo, título de sección ni bloque de contenido se apoya directamente
sobre el fondo de la página.** Todo va dentro de una superficie con borde, radio
y fondo:

```scss
.single {
  box-sizing: border-box;   // sin esto el padding se suma al 100% y sobresale
  width: 100%;
  padding: var(--sl-space-5);
  border: 1px solid var(--mat-sys-outline);
  border-radius: var(--sl-radius-md);
  background: var(--mat-sys-surface);
}
```

Vale para formularios, fichas, listas y cualquier agrupación. El `sl-page` pone
el encabezado; **el cuerpo lo pone la pantalla**, y si no lo pone, los campos
quedan a la intemperie.

Dos consecuencias que se ven enseguida cuando falta:

- **Cada fila termina con un ancho distinto**, porque sin un contenedor que las
  gobierne cada una se mide contra su propio contenido.
- **Los títulos de sección quedan colgando** sobre el fondo, sin nada que los ate
  al bloque que encabezan.

**Y el ancho es el completo.** Nada centrado a la fuerza ni acotado con un
`max-width` propio: el panel es de escritorio y una columna angosta con la mitad
derecha vacía no se parece al resto de las pantallas.

Los campos adentro van en **grilla de cuatro columnas**, que baja a dos por
debajo de 62rem y a una por debajo de 34rem. Un campo suelto por fila produce el
scroll largo que una pantalla de oficina no necesita.

Se escribió el 2026-09-03, después de que el formulario de alta de obra llegara a
revisión con los campos sueltos sobre el fondo y cuatro anchos distintos en la
misma pantalla. La regla ya existía en el código —`customer-form` la cumple desde
SPEC-0009— pero no estaba escrita en ningún lado.

### Una tarjeta no decide su alto

En una grilla de tarjetas, **todas las de una fila miden lo mismo**, sin importar
cuánto contenido tenga cada una. El ítem de la grilla se estira solo; lo que hay
que cuidar es que **se estire lo que se ve**.

Si la tarjeta está envuelta —un `li` con un `a` adentro, que es como se hace una
tarjeta enteramente clickeable— el grid iguala el `li` y el `a` se queda en la
altura de su contenido:

```scss
.cards > li { display: flex; }
.card { flex: 1; }              // la tarjeta llena su ítem
.card__facts { margin: auto 0 0; }   // y la franja de datos se va al pie
```

Sin la tercera línea las tarjetas miden igual pero su contenido queda arriba, y
la franja inferior aparece a distinta altura en cada una — que es el mismo
defecto visual con otro origen.

### Los controles de la barra miden lo que un botón

En el encabezado de una página —buscador, filtros, la acción principal— todo mide
**40px**. Material trae los campos a 56px y los botones a 40px; en la misma fila
se ven de dos tamaños, y el encabezado de esa página queda más alto que el de las
demás. El campo se compacta una sola vez en `styles.scss`, para todo lo que esté
dentro de `.page__header`, con los valores de la densidad -4 de Material. Los
formularios siguen a 56px: ahí la altura es lo que hace cómodo escribir.

**Componente** — solo consume.

```scss
// project-card.component.scss
.card {
  background: var(--sl-color-surface);
  color: var(--sl-color-text);
  border: 1px solid var(--sl-color-border);
  border-radius: var(--sl-radius-md);
  padding: var(--sl-space-4);
}
```

**Un valor literal en el archivo de un componente es un error de revisión.**
Cero excepciones para colores. Si el token que hace falta no existe, se agrega
a la capa semántica — no se hardcodea y se sigue, porque eso es exactamente cómo
se acumula el desorden.

## 3. Formularios

El parcial es `apps/web/src/styles/_form.scss`. **Se consume, no se copia**: si
una pantalla escribe su propio layout de formulario, en tres meses hay cuatro
formularios distintos.

```scss
@use '../../../../styles/form' as form;

.form   { @include form.surface; }
.block  { @include form.block; }
.fields { @include form.fields; }
@include form.widths;
.footer { @include form.footer; }
```

### El ancho lo declara el dato, no el espacio que sobra

Rejilla de **12 columnas** — divisible por 2, 3 y 4, así que un campo ocupa medio,
un tercio o un cuarto de fila sin inventar fracciones. Cada campo elige su clase
por **lo que contiene**:

| Clase | Columnas | Para |
|---|---|---|
| `field--date` | 2 | Fecha, código postal, cantidad |
| `field--short` | 3 | Estado, tipo, unidad, provincia |
| `field--medium` | 4 | Nombre de pila, apellido, empresa |
| `field--long` | 6 | Nombre completo, correo, dirección |
| `field--full` | 12 | Descripción, notas, lo que se escribe largo |

**Las clases de una fila tienen que sumar 12.** Si suman más, el último campo baja
solo y deja un hueco: `6 + 4 + 4` manda "Estado" a una fila propia; `6 + 3 + 3` no.

Antes de esto los anchos salían del slot: una fecha medía **376px** para
`dd/mm/aaaa` y la descripción **1550px**. Un campo cuyo ancho no guarda relación
con su contenido es lo que hace que un formulario se lea como una plantilla.

### El formulario ocupa el ancho de la pantalla

Igual que las listas. **No se acota con un `max-width` propio**: eso deja una
franja muerta a la derecha —medidos 488px en una pantalla de 1920— y el
encabezado, que sí va a ancho completo, deja de compartir borde con él.

Lo que impide que los campos se estiren sin sentido no es angostar la superficie,
es que **cada fila sume 12**. Si una sección no tiene con qué llenar su fila, la
sección está mal armada: dos fechas solas nunca van a llenar 12 columnas, así que
las fechas viven en la fila del trabajo y no en un bloque propio.

*Se decidió así el 2026-09-04, después de probar las dos alternativas. Acotar el
formulario resolvía los anchos por campo y creaba un vacío peor.*

> **Cuidado con el `box-sizing`.** No hay reset global. Toda caja que combine un
> ancho declarado con `padding` necesita `box-sizing: border-box`, o el padding se
> suma por fuera: el encabezado llegó a sobresalir exactamente 50px, que son sus
> 24px de padding por lado más 1px de borde.

### El pie va pegado al último grupo

No al fondo de la pantalla. Un formulario corto no deja 200px de aire antes de
sus botones. Y **los dos botones miden lo mismo**: `--sl-touch-target-primary` es
el objetivo táctil del móvil, no la altura de un botón de escritorio, y aplicado
a uno solo dejaba "Guardar" 12px más alto que "Cancelar" en la misma fila.

### La acción de crear vive dentro del desplegable

Cuando un campo necesita ofrecer "y si no existe, créalo", **no se pone un botón
al lado**: se agrega una última opción al propio `mat-select`, separada por una
línea y en el color de la acción.

```html
<mat-select (valueChange)="onCustomer($event)">
  @for (c of customers(); track c.id) { <mat-option [value]="c.id">…</mat-option> }
  <mat-option [value]="CREAR" class="option--new">Nuevo cliente</mat-option>
</mat-select>
```

Un botón adosado a un campo nunca se alinea del todo —el campo crece hacia abajo
con su ayuda y el botón no—, ocupa una columna de la rejilla que el dato no pidió,
y en estado deshabilitado queda flotando como un fantasma gris. Dentro del menú no
tiene ninguno de esos problemas y aparece justo donde alguien descubre que le
falta el dato.

`.option--new` vive en `styles.scss` y no en la pantalla: el overlay de Material
se renderiza fuera del componente y los estilos encapsulados no lo alcanzan.

### Agrupar es separar

Los campos de un grupo van a `--sl-space-3`; entre grupos, `--sl-space-4` más una
línea. Sin esa diferencia el formulario es una lista de campos, no una ficha con
partes.

Cada grupo lleva su título en `--sl-font-size-body` y peso `bold`. **No en
mayúsculas ni con tracking**: eso es un eyebrow de landing, y esto es una
herramienta.

## 4. Encabezado de página

Lo pone `sl-page` y ninguna pantalla dibuja el suyo. Tres reglas que ya costaron
un bug cada una:

- **Todo mide 40px** — buscador, filtros y acción principal. Material trae los
  campos a 56 y los botones a 40; en la misma fila se ven de dos tamaños.
- **El encabezado envuelve, y lo dispara el espacio disponible, no una media
  query.** Forzar el salto por breakpoint baja las acciones aunque quepan. Y sin
  envolver, el título se comprime hasta **0px** y la acción principal queda
  cortada por el `overflow: hidden`, sin scroll para alcanzarla. Pasaba a 1024px,
  el ancho de laptop más común, y no era progresivo: 900 andaba y 1024 no.
- **Lo que está en el encabezado no se comprime.** `flex: none` en los botones y
  `white-space: nowrap` en su etiqueta, o "Nueva obra" se parte en dos renglones
  dentro de una caja de 40px.

> La etiqueta de un botón de Material vive en `.mdc-button__label`, y cuando el
> botón se proyecta con `ng-content` hacia `sl-page` **ninguno de los dos
> componentes la alcanza** con sus estilos encapsulados. Esa regla va en el
> global.

## 5. Diálogos

- **Ancho `40rem`**, con `maxWidth: calc(100vw - 2rem)`. Un diálogo más ancho deja
  de leerse como una decisión acotada.
- **El contenido arranca con aire arriba.** `mat-dialog-content` recorta lo que se
  sale, y el label flotante del primer campo sobresale unos 6px por encima de su
  borde: sin `padding-top` en el envoltorio de los campos, se ve cercenado. Se
  resuelve con el envoltorio, no peleándole a Material — y ese envoltorio sale de
  `_form.scss`, no se escribe en cada diálogo.
- **Devuelve lo que creó, no un `true`.** Quien abrió el diálogo casi siempre
  necesita dejar seleccionado lo que se acaba de crear.
- **Lo que el diálogo creó ya existe al cerrarse.** No es un borrador que se
  guarda con el formulario que lo abrió: si ese formulario después falla, lo
  creado se conserva y no se deshace.
- Pie a la derecha, la acción secundaria primero, y **barra de progreso de 4px**
  entre el contenido y el pie mientras se guarda.

### Los campos de un diálogo salen del mismo parcial

Dos formas, y la elección es por cuántos campos hay:

```scss
.fields { @include form.dialog-stack; }     // dos o tres campos, apilados
```

```scss
.fields { @include form.dialog-fields; }    // la rejilla adentro del diálogo
@include form.widths-contained;
```

**El breakpoint mira al contenedor, no al viewport.** Un diálogo mide 40rem con el
navegador a 1920 y con el navegador a 1100, así que `@media` no tiene nada que
decir ahí: `widths-contained` pregunta por `@container` y `dialog-fields` declara
el `container-type` que hace falta para medir. Es el mismo juego de anchos
`field--*` de la pantalla completa, con un solo escalón —a 24rem todo se apila—
porque entre eso y el ancho del diálogo no hay lugar para uno intermedio.

Un diálogo cuyos campos ocupan todos la fila entera **no necesita rejilla**:
`dialog-stack` es esa misma columna sin las doce columnas de por medio. La rejilla
entra cuando hay pares que compartir fila.

## 6. Los dos temas, desde el primer componente

El tema se aplica con `data-theme` en el `<html>`, y el default respeta la
preferencia del sistema:

```ts
// theme.service.ts
type Theme = 'light' | 'dark' | 'system';

setTheme(theme: Theme): void {
  const resolved = theme === 'system'
    ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
    : theme;
  document.documentElement.setAttribute('data-theme', resolved);
}
```

**Por qué importa en este producto y no es cosmético.** La misma app se usa en un
techo con sol directo y en un sótano sin luz. El tema no es una preferencia
estética del usuario, es legibilidad en condiciones reales de uso.

Consecuencia práctica: el contraste de texto sobre fondo debe cumplir **WCAG AA
(4.5:1)** en los dos temas. Un gris clarito que se ve elegante en el monitor es
invisible en una pantalla al sol.

Un componente que solo se probó en claro está sin terminar.

## 7. Flutter — la misma regla, otra sintaxis

Los widgets no llevan valores de estilo literales. Consumen el tema.

```dart
// ❌
Container(
  padding: const EdgeInsets.all(16),
  color: const Color(0xFF1D4ED8),
  child: Text('Marcar entrada', style: TextStyle(fontSize: 16, color: Colors.white)),
)

// ✅
Container(
  padding: EdgeInsets.all(context.spacing.md),
  color: Theme.of(context).colorScheme.primary,
  child: Text(l10n.clockIn, style: Theme.of(context).textTheme.bodyLarge),
)
```

`ThemeData` se define una vez con `ColorScheme.light` y `ColorScheme.dark`, y los
tokens que Material no cubre (espaciado, radios propios) van en un
`ThemeExtension`. La app declara `theme`, `darkTheme` y `themeMode` desde el
primer commit — no se agrega dark mode después.

## 8. Qué revisar antes de aprobar un cambio de UI

- [ ] ¿El componente tiene sus tres archivos separados?
- [ ] ¿Hay algún color, tamaño o espaciado literal en el `.scss` del componente?
- [ ] ¿Se ve bien en claro **y** en oscuro?
- [ ] ¿El contraste pasa AA en los dos temas?
- [ ] ¿Los tokens nuevos se agregaron a la capa semántica, no al componente?
- [ ] ¿Hay algún texto quemado? (ver [[i18n]])
- [ ] ¿Cada `font-size` lleva su `line-height` hermano?
- [ ] ¿Se consume la **pieza** del token de Material y no su atajo compuesto?
- [ ] ¿Todo el contenido vive sobre una superficie, a ancho completo o de lectura?
- [ ] En una grilla de tarjetas: ¿las zonas equivalentes arrancan a la misma
      coordenada entre vecinas? Medirlo, no mirarlo.
- [ ] En un formulario: ¿las clases de cada fila suman 12? ¿El ancho de cada campo
      corresponde al dato? ¿El encabezado comparte borde con el formulario?
- [ ] ¿La pantalla consume `_form.scss` o volvió a escribir su propia maqueta? Un
      envoltorio de campos, un aviso de error o un gap copiados a mano son el
      mismo error que un hex literal.
- [ ] ¿Alguna caja combina `max-width` con `padding` sin `box-sizing: border-box`?
- [ ] ¿El encabezado sigue usable a 1024px y a 375px? Es donde se rompe primero.

## Pendiente

- [x] ~~**ADR de sistema de diseño**~~ — resuelto en
      [[../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] el 2026-08-08:
      `design-tokens.json` en la raíz, Material 3 nativo en Flutter sin librería
      de componentes, y `ColorScheme` explícito en vez de `ColorScheme.fromSeed`.
- [ ] **Librería de componentes para Angular** — se decide cuando arranque
      `apps/web`, en su propio ADR. Cualquiera que se adopte consume los tokens
      del JSON, no los suyos.
