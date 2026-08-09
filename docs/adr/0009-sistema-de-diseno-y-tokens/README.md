---
id: ADR-0009
title: "Sistema de diseño: tokens canónicos, identidad cálida y Material 3 nativo"
aliases:
  - "ADR-0009: Sistema de diseño: tokens canónicos, identidad cálida y Material 3 nativo"
type: adr
status: propuesto
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/propuesto
  - ui
---

# ADR-0009: Sistema de diseño: tokens canónicos, identidad cálida y Material 3 nativo

> **Meta**
> - Deciders: @jaca
>
> _Estado y fecha viven en el frontmatter arriba — no duplicar aquí._

## Contexto

Este ADR resuelve el pendiente declarado al final de
[[../../code-guidelines/estilos-y-temas|estilos-y-temas.md]]: si se adopta una
librería de componentes y cómo se aplican los tokens.

El riesgo ya estaba escrito en [[../0002-superficies-flutter-angular/README|ADR-0002]]
—deriva visual entre Angular y Flutter— con la mitigación enunciada pero sin
mecanismo: *"los tokens son la fuente de verdad y ninguna superficie define valores
propios"*. Falta decidir **dónde vive esa fuente**.

Al aterrizarlo aparece un choque concreto. La guía de estilos ya fija los colores
como hex explícitos para CSS (`--sl-color-primary: #1d4ed8`), mientras que el
patrón recomendado de Material 3 es `ColorScheme.fromSeed(seedColor: ...)`, que
**deriva** la paleta entera algorítmicamente a partir de un color semilla. Las dos
cosas no pueden convivir: `fromSeed` con semilla `#1d4ed8` no produce `#1d4ed8`
como primario, produce el tono armonizado que le corresponde en su rueda. Usar
`fromSeed` en Flutter y hex explícitos en CSS es exactamente la deriva que el
ADR-0002 quería evitar, solo que introducida por nosotros el primer día.

Restricción de contexto: `apps/web` no tiene scaffold y hay un prototipo
comprometido para la semana del 2026-08-10. Hoy existe una sola superficie.

## Decisión

### 1. `design-tokens.json` en la raíz es la fuente única

Mismo lugar y misma lógica que `openapi.json`: lo consumen superficies que están
dentro del workspace de pnpm (Angular, Astro) y una que está afuera (Flutter), así
que no puede vivir dentro de ninguna.

Las tres capas de la guía de estilos se conservan tal cual: primitivas → semánticos
→ componente. El JSON contiene las dos primeras. **Ninguna superficie define valores
propios**, y un hex literal en un componente sigue siendo error de revisión.

### 2. `ColorScheme` explícito en Flutter, nunca `fromSeed`

Los colores se declaran uno por uno, con los mismos valores del JSON que usa CSS.

Se pierde la armonización automática de Material 3 y hay que elegir a mano los
tonos que M3 derivaría solo. **Se cambia esa comodidad por paridad exacta entre
superficies**, que es lo que el producto necesita: la misma foto de proyecto y el
mismo estado de bandera tienen que verse igual en el teléfono del trabajador y en
el panel de William.

`fromSeed` queda disponible como herramienta de exploración para *elegir* una
paleta nueva. Su salida se congela en el JSON; no se llama en tiempo de ejecución.

### 3. Lo que Material no cubre va en un `ThemeExtension`

Espaciado, radios propios y los colores de bandera de asistencia no tienen lugar
en `ColorScheme` ni en `TextTheme`. Van en una extensión tipada con su `lerp` y su
`copyWith`, y se consumen como `context.spacing.md`, nunca como literales.

### 4. Sin librería de componentes en Flutter

Material 3 nativo. No se adopta una librería de terceros.

La app tiene pocas pantallas y muy específicas —marcar entrada, cámara, lista de
proyectos—, no formularios densos ni tablas. Una librería de componentes agregaría
su propio sistema de theming encima del de Material, que es justo la capa extra que
el pendiente original señalaba como problema.

**La decisión para Angular queda abierta a propósito.** Se toma cuando arranque
`apps/web`, en su propio ADR: las tablas densas de facturación tienen necesidades
que no se pueden evaluar sin haber escrito una pantalla. Lo que sí queda fijo es
que cualquier librería que se adopte **consume los tokens del JSON**, no los suyos.

### 5. La identidad es Snapline, presente y discreta

La app de campo y el panel son Snapline: identidad fija, una sola paleta. La marca
del contratista aparece como **dato** —el perfil de su empresa—, no como revestimiento
de la interfaz. Lo que ve el cliente final —portal por link, fotos publicadas a su
web— sí lleva la marca del contratista, porque esa relación es suya.

Eso descarta el white-label en la app, y con él la capa de tokens por empresa: no
hay color de acento resuelto en runtime ni contraste AA que dependa de un valor que
elige el cliente.

**Dirección cromática: neutro puro con naranja de obra.** Los neutros son `neutral`,
sin tinte en ninguna dirección: `slate` tira a azul y hace ver azuladas las fotos de
obra, y `stone` tira a cálido, lo que en fondos oscuros se lee directamente como
café. El calor de la identidad lo aporta el naranja, no los grises.

### 6. Los estados se distinguen por forma, no por tono

El acento naranja (`#C2410C`) está a **17 grados** del rojo de error y a **18** del
ámbar de las banderas. Medido, no estimado. Naranja, ámbar y rojo viven en unos 35
grados de rueda y no hay dónde moverlos sin romper la convención de "atención" y
"peligro", que en una app usada con guantes no se negocia.

La separación la da entonces la forma:

- El **naranja saturado es exclusivo de la acción primaria**. Un botón sólido por
  pantalla. Si dos cosas son naranjas, ninguna es la acción.
- Los **estados van siempre en su par `container` / `onContainer`** —fondo tenue,
  texto oscuro, icono— nunca en relleno sólido.
- **Ningún estado se comunica solo con color.** El icono es obligatorio: es requisito
  de accesibilidad y, acá, de alguien mirando la pantalla al sol.

Por eso el sistema define `primaryContainer`, `warningContainer`, `dangerContainer`
y `successContainer` con sus `on*`. Sin ese par, la regla no se puede cumplir.

### 7. Dos familias con roles que no se cruzan

| Familia | Dónde | Por qué |
|---|---|---|
| **Inter** | Todo el texto de interfaz | Diseñada para UI, legible en tamaños chicos, cifras tabulares |
| **Bricolage Grotesque** | **Solo el wordmark** | La marca necesita decir algo; Inter es deliberadamente neutra |

Inter sola dejaba el nombre indistinguible de cualquier otra app. Bricolage aporta
carácter y está poco usada, así que la marca no se confunde con otra —que es más
de lo que consiguen Archivo Black u Oswald, que están en todas partes.

**Ningún texto de interfaz usa la familia de marca.** Una display a tamaño de
lectura cansa y compite con el contenido; el wordmark es su único lugar.

Las dos se **embeben como asset**, con su licencia OFL al lado. **No se usa el
paquete `google_fonts`**, que descarga la tipografía en tiempo de ejecución —
inaceptable en una app cuyo caso de uso es una obra sin señal.

Las cifras del cronómetro y de los montos usan `FontFeature.tabularFigures()`: con
dígitos de ancho variable el texto se mueve en cada segundo.

### 7b. La marca tiene dos lockups, y el vertical es el de presencia

`SnaplineLogo` es horizontal y va atenuado: acompaña en barras y encabezados.
`SnaplineLogoStacked` pone el símbolo sobre el nombre y va en el color de texto
pleno: es el de las pantallas donde la marca es lo primero que se ve.

El horizontal **no crece**: pasado cierto tamaño se queda sin ancho antes de tener
presencia, y en un teléfono angosto desborda. Cuando haga falta una marca grande,
es el vertical.

**La textura de fondo (`SnaplineBackdrop`) nunca cruza el símbolo.** El símbolo ya
es una diagonal; una segunda diagonal del mismo gesto por detrás no se lee como
fondo, se lee como parte del logo mal dibujada.

### 8. La traducción a Dart se escribe a mano por ahora

Con una sola superficie viva, montar un pipeline de generación cuesta más de lo que
ahorra. Los tokens se traducen a un único `lib/core/theme/tokens.dart`, revisable
de un vistazo, con el JSON como referencia obligada.

**No es la solución final y se registra como deuda técnica**, con su trigger: el
scaffold de `apps/web`. En ese momento hay dos destinos y la generación automática
—Style Dictionary sobre el mismo JSON— se paga sola.

Lo que **no** se posterga es el JSON. Existe desde hoy, porque el escenario caro no
es escribir un generador tarde: es descubrir que los valores quedaron dispersos
dentro de los widgets y tener que extraerlos de cincuenta archivos.

## Alternativas consideradas

### Alternativa A — `ColorScheme.fromSeed` en Flutter, hex explícitos en CSS

Lo idiomático en cada plataforma por separado.

**Por qué no:** produce dos paletas distintas desde el primer commit. La deriva no
sería un riesgo a vigilar, sería el estado inicial.

### Alternativa B — Semilla compartida, derivando la paleta en las dos superficies

Se comparte el `seedColor` y cada superficie deriva con el algoritmo de M3.

**Por qué no:** obligaría a portar el algoritmo de Material a CSS para que dé lo
mismo. Es más trabajo que escribir los hex, y queda atado a que ese algoritmo no
cambie entre versiones de Flutter.

### Alternativa C — Style Dictionary y el pipeline completo desde hoy

La solución correcta a término.

**Por qué no todavía:** hay un solo consumidor. Con `apps/web` sin scaffold, el
generador estaría generando un único archivo que igual hay que revisar a mano.
Se difiere con trigger explícito, no se descarta.

### Alternativa D — Tokens dentro de `packages/`

Encaja con el workspace de pnpm y se versionaría como paquete.

**Por qué no:** Flutter está fuera del workspace por diseño (ADR-0007) y tendría
que alcanzar el archivo por una ruta relativa que atraviesa `packages/`. El mismo
argumento que puso a `openapi.json` en la raíz aplica igual.

## Consecuencias

### Positivas

- Un cambio de color se hace en un archivo y las dos superficies lo toman del mismo
  valor, sin conversión ni interpretación.
- El modo oscuro existe como token desde el primer widget, que es lo que exige la
  regla 23 y lo que evita retrofitearlo tocando todos los componentes.
- El contraste AA se verifica una vez sobre el JSON, no superficie por superficie.

### Negativas / Costos

- Elegir a mano los tonos que M3 derivaría solo: `surfaceContainerHighest`,
  `onPrimaryContainer` y compañía. Es trabajo real la primera vez.
- Un archivo de tokens en Dart mantenido a mano hasta que llegue el generador, con
  la ventana de desincronización que eso abre.

### Riesgos

- **Que el JSON y `tokens.dart` se separen.** Es el costo directo de la decisión 5.
  Mitigación: queda en `docs/tech-debt/` con su trigger, y el `code-reviewer`
  compara los dos archivos cuando cambia cualquiera.
- **Que un `ColorScheme` incompleto rompa componentes de Material.** M3 usa roles
  que no aparecen en la guía de estilos; si alguno queda sin definir, el widget cae
  a un default que no es de la paleta. Mitigación: se declaran todos los roles del
  `ColorScheme`, no solo los que hoy se usan.

## Impacto en el modelo

Ninguno.

## Referencias

- [[../../code-guidelines/estilos-y-temas|estilos-y-temas.md]] — este ADR cierra su
  sección "Pendiente".
- [[../0002-superficies-flutter-angular/README|ADR-0002]] — de dónde sale el riesgo
  de deriva visual.
- [[../0008-arquitectura-flutter/README|ADR-0008]] — dónde encaja `core/theme` en
  la estructura de la app.
- Reglas 21, 22 y 23 del `CLAUDE.md` raíz.
- Verificado con Context7 el 2026-08-08: patrón de theming de Material 3 en Flutter.
