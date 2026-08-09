---
id: DIAGRAMS-README
title: "Diagramas — convención"
type: index
tags:
  - index
  - diagrams
  - excalidraw
---

# 📐 Diagramas (Excalidraw)

Convención completa. El cheatsheet técnico para armar el JSON está en
[[GUIA-JSON]].

## Cuándo hacer un diagrama

Solo cuando aporta **algo que el texto no comunica igual de rápido**: estructura
espacial, relaciones múltiples cruzadas, jerarquía visual.

**Si el diagrama termina siendo "el MD pero en cajas", no lo hagas.** Un diagrama
redundante envejece peor que el texto, porque nadie lo actualiza cuando cambia la
decisión.

## Dónde vive

**Regla de oro: el diagrama vive junto al documento que ilustra.** Esta carpeta es
el fallback, no el default.

### Co-localizado — preferido

```
docs/
├─ domain/
│  ├─ proyecto.md
│  └─ mapa-dominio.excalidraw.md         ← mapa canónico de agregados
├─ specs/web/0007-facturacion/
│  ├─ README.md
│  └─ flujo-facturacion.excalidraw.md
└─ adr/0003-asistencia-geocerca-foto/
   ├─ README.md
   └─ verificacion-asistencia.excalidraw.md
```

### En `_diagrams/` — fallback

Solo si el diagrama es **global** (arquitectura general, stack), **no pertenece a
un solo doc** (un flujo que cruza varios specs y ADRs), o es un borrador que
todavía no sabés dónde termina.

## Nombres

| Tipo | Nombre |
|---|---|
| Ilustra un doc específico | Mismo nombre que el doc + `.excalidraw.md` |
| Global / arquitectura | `arquitectura-{tema}.excalidraw.md` |
| Dominio | `dominio-{agregado}.excalidraw.md` |
| Flujo de UI | `flujo-{feature}.excalidraw.md` |

## Reglas duras de contenido

El diagrama es **visual puro**, no documentación en formato canvas.

### Sí va en el canvas

- Cajas con **etiquetas mínimas**: nombre + 2-4 campos clave, los que hacen falta
  para entender la relación con las otras cajas
- **Grupos visuales** con background de baja opacidad (25–30%) y label del grupo
  arriba a la izquierda
- **Flechas curvas** (`roundness: { "type": 2 }`) con cardinalidades cortas:
  `1:1`, `1:N`, `N:1`, `M2M`
- Título arriba a la izquierda, fuera del área de cajas
- `link` en las cajas cuando el diagrama sirve de índice navegable

### No va en el canvas

- **Listados completos de campos** de una entidad — eso es la tabla del MD
- **Tablas comparativas** de cualquier tipo
- Advertencias largas, justificaciones, párrafos explicativos
- Bullets que repiten una sección del MD
- **Cualquier texto que el lector ya leyó** en el `.md` que embebe el diagrama

Si tenés que escribir más de un par de palabras dentro de una caja, esa
información pertenece al MD.

## Cómo crear uno

```
/diagram-new <nombre> [ubicación]

/diagram-new mapa-dominio domain
/diagram-new arquitectura-general _diagrams
```

Desde Obsidian: click derecho en una carpeta → "Create new drawing".

## Cómo embeberlo

```markdown
![[mapa-dominio.excalidraw]]
```

Obsidian lo resuelve buscando en todo el vault y lo renderiza inline. Cmd+click en
una caja con `link` lleva al archivo enlazado — así el mapa del dominio funciona
como índice visual.

## Sin compresión, a propósito

El plugin se configura con **`compress: false`**. Los archivos quedan como markdown
legible con el JSON adentro, en vez de base64 comprimido.

Esto es lo que permite que Claude lea y edite diagramas programáticamente. Si se
activa la compresión, los diagramas se vuelven opacos y solo se pueden editar a
mano desde Obsidian.

## Quién dibuja qué

**Claude deja el borrador, el humano lo acomoda.** Cuando hay información
suficiente en el vault, Claude genera las cajas, flechas y grupos; después se
mueven y se ajusta la estética desde Obsidian.

Un primer borrador imperfecto vale más que un canvas en blanco. Un canvas vacío
no lo puebla nadie.

## Modo oscuro

El plugin de Excalidraw invierte los colores automáticamente cuando Obsidian está
en tema oscuro, así que los diagramas se hacen con la paleta clara y funcionan en
los dos. No hay que mantener dos versiones — es la única parte del proyecto donde
la regla 23 no aplica.

## Diagramas actuales

```dataview
LIST
FROM "domain" OR "specs" OR "adr" OR "_diagrams" OR "product"
WHERE contains(file.name, "excalidraw")
SORT file.path ASC
```
