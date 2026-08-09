---
id: DIAGRAMS-GUIA-JSON
title: "Guía JSON Excalidraw — cheatsheet"
type: guide
tags:
  - diagrams
  - excalidraw
  - internal
---

# Cheatsheet JSON Excalidraw

Esta guía es **para Claude**, no para humanos. Documenta la estructura
mínima de los elementos de Excalidraw para que pueda generar diagramas
programáticamente con confianza.

## Filosofía — qué SÍ y qué NO va en un diagrama

> **Regla de oro**: el diagrama es **visual puro**. Si la información ya
> está en el `.md` adjunto, no la pongas también en el canvas.

### ✅ Sí va en el canvas
- Cajas / nodos con **etiquetas mínimas**: nombre + 2-4 campos clave (los
  que el lector necesita para entender la relación con otras cajas).
- **Grupos visuales** con backgrounds suaves (opacity 25-30%) y un label
  del grupo arriba a la izquierda.
- **Flechas curvas** con cardinalidades cortas (`1:1`, `1:N`, `N:1`, `M2M`,
  `owner`, `M:N`). Preferí `roundness: { "type": 2 }` + puntos intermedios
  por sobre flechas rectas con elbow.
- **Título** del diagrama arriba a la izquierda, fuera del área de cajas.

### ❌ NO va en el canvas
- **Listados completos de campos de una entidad** — eso es la tabla del MD.
- **Tablas comparativas** "viejo vs nuevo" o "antes vs después".
- **Secciones del tipo "⚠ Decisiones que NO se replican"**, advertencias
  largas, justificaciones, párrafos explicativos.
- **Bullets que repiten una sección del MD** ("•  X mezclaba responsabilidades…").
- **Cualquier texto que el lector ya leyó en el `.md`** que embebe el diagrama.

Si tenés que escribir más de un par de palabras dentro de una caja o como
nota suelta, esa info pertenece al MD, no al canvas.

### Precedente canónico

`docs/domain/mapa-dominio.excalidraw.md` — seis zonas agrupadas por área
(tenencia, obra, campo, comercial, cliente, publicación), cajas con nombre + 2-4
campos clave, flechas curvas con cardinalidades, sin texto duplicado del MD.
Cada caja lleva `link` al agregado, así que el mapa funciona como índice navegable.

## Estructura raíz

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.22.0",
  "elements": [ /* array de elementos */ ],
  "appState": {
    "gridSize": 20,
    "gridStep": 5,
    "gridModeEnabled": false,
    "viewBackgroundColor": "#ffffff"
  },
  "files": {}
}
```

## Campos comunes a todos los elementos

```json
{
  "id": "<string único en el diagrama>",
  "type": "<rectangle|ellipse|diamond|text|arrow|line|freedraw>",
  "x": 0,
  "y": 0,
  "width": 200,
  "height": 80,
  "angle": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "seed": 1,
  "version": 1,
  "versionNonce": 100000001,
  "isDeleted": false,
  "groupIds": [],
  "frameId": null,
  "roundness": { "type": 3 },
  "boundElements": [],
  "updated": 1,
  "link": null,
  "locked": false
}
```

**Convenciones de IDs — CRÍTICO:**

- **Elementos de texto** (`"type": "text"`): usar IDs de **8 caracteres alfanuméricos**
  estilo Obsidian (ej: `sGH3kP2r`, `Bm9xLqW5`). Obsidian reemplaza IDs de texto
  que no sigan este patrón con los suyos propios, rompiendo la sincronía con
  `## Text Elements` y generando duplicados visibles.
- **Elementos no-texto** (rectangles, arrows, lines, frames): pueden usar IDs
  descriptivos cortos sin guiones (ej: `sesBox01`, `arrSesRt`, `bgTitle1`).
  Obsidian no reemplaza estos IDs.
- **Nunca** usar guiones en IDs de text elements (`ses-label`, `agg-title`, etc.)
  — Obsidian los reemplaza.

- `seed`: cualquier número. No hace falta aleatorio, usa incremental.
- `version` y `versionNonce`: 1 y un número creciente. No importa el valor
  exacto, Excalidraw los actualiza al editar.
- `updated`: 1 sirve.
- `roundness: { "type": 3 }` para rectángulos con esquinas redondeadas.
  `null` para esquinas rectas.

## Paleta de colores Excalidraw estándar

| Color | Hex |
| --- | --- |
| Negro | `#1e1e1e` |
| Gris | `#868e96` |
| Rojo | `#e03131` |
| Naranja | `#f08c00` |
| Amarillo | `#fab005` |
| Verde | `#2f9e44` |
| Azul | `#1971c2` |
| Violeta | `#6741d9` |
| Rosa | `#c2255c` |

Fondos claros (para backgroundColor):

| Color | Hex |
| --- | --- |
| Rojo pálido | `#ffc9c9` |
| Naranja pálido | `#ffec99` |
| Verde pálido | `#b2f2bb` |
| Azul pálido | `#a5d8ff` |
| Violeta pálido | `#d0bfff` |

## Rectángulo

```json
{
  "type": "rectangle",
  "id": "box-api",
  "x": 0,
  "y": 0,
  "width": 200,
  "height": 80,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "#a5d8ff",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "angle": 0,
  "seed": 1,
  "version": 1,
  "versionNonce": 100000001,
  "isDeleted": false,
  "groupIds": [],
  "frameId": null,
  "roundness": { "type": 3 },
  "boundElements": [
    { "type": "text", "id": "text-api" }
  ],
  "updated": 1,
  "link": null,
  "locked": false
}
```

`boundElements` con `"type": "text"` vincula un label **centrado** dentro
del rectángulo. El texto debe declarar `containerId: "box-api"` recíprocamente.

⚠ **Evitar este patrón para diagramas de entidades** (tipo tabla con título +
campos). Obsidian reposiciona el texto al centrar en el container, lo que
superpone el título con los campos. Usar texto posicionado manualmente
(`containerId: null`, `autoResize: false`) en su lugar.

## Texto

**Texto libre (no dentro de una caja):**

```json
{
  "type": "text",
  "id": "title-main",
  "x": 0,
  "y": 0,
  "width": 400,
  "height": 36,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "angle": 0,
  "seed": 1,
  "version": 1,
  "versionNonce": 100000001,
  "isDeleted": false,
  "groupIds": [],
  "frameId": null,
  "roundness": null,
  "boundElements": [],
  "updated": 1,
  "link": null,
  "locked": false,
  "fontSize": 28,
  "fontFamily": 1,
  "text": "Título",
  "textAlign": "center",
  "verticalAlign": "top",
  "containerId": null,
  "originalText": "Título",
  "lineHeight": 1.25,
  "baseline": 25
}
```

**Texto dentro de una caja (label de rectángulo/elipse/diamond):**

Igual que el anterior, pero:

- `containerId`: id del rectángulo contenedor.
- `textAlign: "center"`, `verticalAlign: "middle"`.
- `x`, `y`, `width`, `height`: Excalidraw los recalcula en base al container,
  pero igual hay que ponerlos. Usa el centro del rectángulo.

**Tamaños de fuente:**

- `fontSize: 28` → título grande.
- `fontSize: 20` → subtítulo.
- `fontSize: 16` → label de caja estándar.
- `fontSize: 14` → texto chico / nota.

**`fontFamily`:**

- `1` → Virgil (handwriting, default Excalidraw).
- `2` → Helvetica.
- `3` → Cascadia (mono).

**`baseline`:** aproximadamente `fontSize * 0.9`. No es crítico.

## Elipse

Igual que rectángulo pero `"type": "ellipse"`. Útil para "inicio" / "fin" en
flowcharts, o para usuarios / actores.

## Diamond

Igual que rectángulo pero `"type": "diamond"`. Útil para decisiones en flowcharts.

## Flecha

```json
{
  "type": "arrow",
  "id": "arrow-api-to-db",
  "x": 200,
  "y": 40,
  "width": 150,
  "height": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "angle": 0,
  "seed": 1,
  "version": 1,
  "versionNonce": 100000001,
  "isDeleted": false,
  "groupIds": [],
  "frameId": null,
  "roundness": { "type": 2 },
  "boundElements": [],
  "updated": 1,
  "link": null,
  "locked": false,
  "points": [
    [0, 0],
    [150, 0]
  ],
  "lastCommittedPoint": null,
  "startBinding": {
    "elementId": "box-api",
    "focus": 0,
    "gap": 5
  },
  "endBinding": {
    "elementId": "box-db",
    "focus": 0,
    "gap": 5
  },
  "startArrowhead": null,
  "endArrowhead": "arrow",
  "elbowed": false
}
```

**Clave:**

- `x`, `y`: coordenada del primer punto (el origen local de la flecha).
- `points`: array de `[dx, dy]` relativos al origen. `[[0,0], [150, 0]]` =
  flecha horizontal de 150 de ancho.
- `startBinding` / `endBinding`: conectan la flecha a dos cajas por id.
  `focus: 0` = centro. `gap: 5` = separación en px.
- `endArrowhead: "arrow"` para cabeza tipo flecha. `"triangle"`, `"bar"`,
  `"dot"` también válidos. `null` = sin cabeza.

**Para flecha con label:** agregá en `boundElements` un `{ "type": "text", "id": "..." }`
y creá un text element con `containerId` apuntando a la flecha. El texto se
coloca a la mitad de la flecha automáticamente.

**Flechas elbowed** (en ángulos rectos): `"elbowed": true`. Excalidraw
calcula el path con esquinas.

## Línea

Igual que flecha pero `"type": "line"`, sin `startArrowhead`/`endArrowhead`.

## Frame (agrupador visual)

```json
{
  "type": "frame",
  "id": "frame-apps",
  "x": -300,
  "y": -100,
  "width": 800,
  "height": 400,
  "name": "apps/",
  "strokeColor": "#bbbbbb",
  ...
}
```

Los elementos dentro declaran `frameId: "frame-apps"`.

## Grupos

Los elementos que comparten `groupIds: ["group-1"]` se mueven juntos.
Útil para cajas con su label.

## Layout manual — sugerencias

- **Flowcharts horizontales**: cajas cada 250px en `x`, todas con mismo `y`.
- **Flowcharts verticales**: cajas cada 150px en `y`, todas con mismo `x`.
- **Arquitectura en capas**: usa frames, una capa por frame (ej: frame
  "apps/" arriba, "packages/" abajo).
- **Deja aire**: entre cajas, al menos 60-100px.
- **Títulos**: arriba del canvas, centrados. `y: -240` o similar para
  que queden separados de las cajas.

## Errores comunes (lecciones aprendidas)

### 1. Flechas sueltas: los `points` deben llegar al borde

**Síntoma**: las flechas se dibujan pero aparecen flotando cerca de las cajas,
no conectadas.

**Causa**: Excalidraw respeta `startBinding`/`endBinding` sólo si las
coordenadas físicas (`x`, `y`, `points`) **ya llegan** a los bordes de las cajas.
No recalcula el path al abrir — sólo cuando movés la caja en el editor.

**Fix**: calculá las coordenadas de los bordes manualmente.

```
caja A:  x=-320, y=-340, width=180, height=100
  → borde bottom-center = (-320+90, -340+100) = (-230, -240)

caja B:  x=-200, y=80, width=220, height=100
  → borde top-center = (-200+110, 80) = (-90, 80)

flecha:
  x = -230, y = -240             ← origen en borde de A
  points = [[0,0], [140, 320]]   ← dx=140, dy=320 hasta borde de B
  width = 140, height = 320      ← igual que el delta
```

### 2. `fixedPoint` en bindings (Excalidraw moderno)

Excalidraw ahora usa `fixedPoint: [x_ratio, y_ratio]` (0..1) dentro del binding
para indicar dónde se ancla en la caja. Convención:

```json
"fixedPoint": [0.5, 0]    // centro superior
"fixedPoint": [0.5, 1]    // centro inferior
"fixedPoint": [0, 0.5]    // centro izquierdo
"fixedPoint": [1, 0.5]    // centro derecho
```

Úsalo junto con `gap: 1` (Excalidraw nuevo prefiere gaps chicos, no 5-10).

### 3. Sincronía entre `## Text Elements` y JSON — CRÍTICO

**Síntoma**: texto superpuesto, duplicado o con `^id` visible en el canvas.

**Causa**: el plugin hace un doble parse del archivo:
1. Lee `## Text Elements` y mapea cada bloque de texto al `^id` correspondiente.
2. Compara esos IDs contra los `"id"` de los text elements en el JSON.
3. Si un `^id` no tiene correspondencia en el JSON, Obsidian crea un **nuevo**
   elemento de texto con un ID generado automáticamente, dejando el original
   huérfano — resultado: texto duplicado en el canvas.

**Regla de oro**: cada entrada en `## Text Elements` con `^someId` DEBE tener
un elemento en el JSON con `"id": "someId"` y `"text"` idéntico al texto antes
del `^`.

**Template correcto:**

```markdown
## Text Elements
Título del agregado ^sGH3kP2r

Session ^Bm9xLqW5

campo1: tipo
campo2: tipo? ^Tn7vRe4k
```

```json
{ "id": "sGH3kP2r", "type": "text", "text": "Título del agregado", ... },
{ "id": "Bm9xLqW5", "type": "text", "text": "Session", ... },
{ "id": "Tn7vRe4k", "type": "text", "text": "campo1: tipo\ncampo2: tipo?", ... }
```

**⚠ IDs de texto deben ser 8 chars alfanuméricos** (ver sección Convenciones de IDs).
Obsidian reemplaza IDs con guiones en text elements y desincroniza el archivo.

**Son 8 exactos, no "alrededor de 8".** Caso real (2026-07-28,
`0100-pantalla-mep-calendario-oficial/old-arquitectura-mep.excalidraw.md`): cuatro
text elements con IDs de **9** caracteres (`BxCalMep1`, `BxHolSrv1`, `BxHolTbl1`,
`LbRowDay1`) fueron reasignados por Obsidian al abrir el archivo. El daño no fue
solo el rename: al reconciliar `## Text Elements` contra el JSON, la lista se
corrió y **el texto de una caja sobreescribió la etiqueta de una flecha**, que
además quedó reposicionada encima del dibujo. El JSON validaba perfecto y los
anchors cuadraban antes de abrirlo — el problema solo aparece al renderizar en
Obsidian. Verificá el largo de los IDs antes de dar un diagrama por terminado:

```bash
python3 -c "
import re,json
s=open('ruta/al.excalidraw.md').read()
d=json.loads(re.search(r'\`\`\`json\n(.*?)\n\`\`\`',s,re.S).group(1))
print([e['id'] for e in d['elements'] if e['type']=='text' and len(e['id'])!=8] or 'ok')
"
```

### 4. `boundElements` bidireccional obligatorio

- **Caja ↔ label**: caja dice `"boundElements": [{"type":"text","id":"text-x"}]`,
  texto dice `"containerId":"box-x"`.
- **Caja ↔ flecha**: caja dice `"boundElements": [{"type":"arrow","id":"arrow-x"}]`,
  flecha dice `"startBinding": {"elementId":"box-x",...}` o `endBinding`.
- Olvidar uno de los dos lados causa que el binding no persista al re-abrir.

### 5. `fillStyle: "solid"` + `backgroundColor: "transparent"`

La caja no tiene relleno. Para relleno visible, dar un color a `backgroundColor`.

### 6. `index: "a0"`, `"a1"`, ..., `"aA"`, `"aB"`...

Excalidraw usa `index` (fractional indexing) para orden de z-stack. Usa
letras/numeros crecientes: `a0, a1, a2, ..., a9, aA, aB, ..., aZ, aa, ab`.
Si falta, Excalidraw lo genera — pero ponerlo explícito evita reordenamiento
al abrir.

### 7. `autoResize` y `containerId` en text elements

**Para texto posicionado manualmente** (la mayoría de los casos en diagramas
generados por Claude):

```json
"containerId": null,
"autoResize": false
```

`autoResize: false` + `containerId: null` previene que Obsidian reposicione
el texto al abrir el archivo. Con `autoResize: true`, Obsidian puede mover
el texto si considera que no cabe en su contenedor implícito.

**Excepción**: labels de flechas usan `containerId: "id-de-la-flecha"` y
`autoResize: false`. Obsidian los posiciona en el centro de la flecha
automáticamente — eso es correcto y deseado.

**NO usar `containerId` de un rectángulo en text elements** salvo que
explícitamente quieras que Obsidian centre el texto dentro del rect.
En ese caso, el rectángulo también debe declarar el binding en `boundElements`.
Para entidades tipo tabla (título + campos), es mejor posicionar el texto
manualmente con coordenadas explícitas.

## Pattern: zonas agrupadas con backgrounds

Para diagramas con varias entidades relacionadas, agrupar visualmente por
zona temática (ej. "Identidad", "Multi-tenancy", "Comercial") usando un
rectángulo de fondo con baja opacidad y un label arriba a la izquierda.

```json
// Background de la zona
{
  "id": "bgZona1",
  "type": "rectangle",
  "x": -640, "y": -120, "width": 520, "height": 320,
  "strokeColor": "#1971c2",          // borde del color de la zona
  "backgroundColor": "#a5d8ff",      // fill claro a juego
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "dashed",           // dashed lo separa visualmente del foreground
  "opacity": 30,                      // 25-30 — visible pero no protagonista
  "roundness": { "type": 3 },
  "groupIds": ["grpZona1"]
}

// Label de la zona (arriba a la izquierda del background)
{
  "id": "lblZona1",
  "type": "text",
  "x": -620, "y": -110,
  "fontSize": 18,
  "strokeColor": "#1971c2",
  "text": "Identidad",
  "groupIds": ["grpZona1"]
}
```

Tip: usá la paleta de fondos pálidos (`#a5d8ff`, `#b2f2bb`, `#ffe8cc`,
`#d0bfff`, `#ffc9c9`) emparejada con el color fuerte del mismo tono para
borde y label. Una zona = un color.

## Pattern: flechas curvas con cardinalidad

Para que las flechas se vean curvas (no rectas con elbow):

```json
{
  "id": "arrAB",
  "type": "arrow",
  "x": -110, "y": -30,                  // origen en borde de caja A
  "width": 130, "height": -110,         // delta hasta borde de caja B
  "strokeWidth": 2,
  "roundness": { "type": 2 },           // CRÍTICO: type 2 = curva
  "endArrowhead": "arrow",
  "points": [
    [0, 0],
    [60, -90],                          // punto intermedio para curvar
    [130, -110]
  ]
}
```

Y el label de cardinalidad como texto suelto cerca del centro de la flecha
(no como `containerId` de la flecha, para mantener control de la posición):

```json
{
  "id": "lblAB",
  "type": "text",
  "x": -50, "y": -100,
  "fontSize": 14,
  "strokeColor": "#868e96",             // gris para que no compita con la línea
  "text": "M2M"
}
```

**Cardinalidades cortas** estándar: `1:1`, `1:N`, `N:1`, `M2M`, `M:N`.
Para semántica especial (`owner (1:N)`, `eager`, `nullable`) escribir
explícito pero corto.

## Template mínimo utilizable

El template de `/diagram-new` usa solo un text element (título). Para
diagramas con contenido, copiar la estructura de
`docs/domain/mapa-dominio.excalidraw.md` (precedente canónico — zonas agrupadas,
flechas curvas con cardinalidades, cajas linkeadas, sin texto duplicado).
