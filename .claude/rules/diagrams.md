---
paths:
  - "**/*.excalidraw.md"
---

# Diagramas (Excalidraw)

Convención completa en `docs/_diagrams/README.md`. Cheatsheet del JSON en
`docs/_diagrams/GUIA-JSON.md`.

## Formato y ubicación

- **`.excalidraw.md`, sin comprimir.** El plugin está en `compress: false`, así que
  el JSON del bloque ` ```json ` se lee y se edita directamente. No activar
  compresión: vuelve los diagramas opacos para todo lo que no sea Obsidian.
- **Co-localizados con el doc que ilustran.** Un diagrama de
  `docs/adr/0003-asistencia-geocerca-foto/README.md` vive en esa misma carpeta.
  Los globales van a `docs/_diagrams/`.
- **Crear con** `/diagram-new <nombre> [ubicación]`.
- **Embeber con** `![[nombre.excalidraw]]`.

## Mapa de dominio

`docs/domain/mapa-dominio.excalidraw.md` es el mapa canónico de todos los
agregados. **Cada vez que `/domain-new` crea un agregado, se le agrega su caja al
mapa**, con `"link": "[[slug|Nombre]]"` para que sea navegable. Claude agrega la
caja al JSON; el humano ajusta la posición en Obsidian.

Un agregado que no está en el mapa es un agregado que nadie ve.

## Reglas duras de contenido

El diagrama es **visual puro**, no documentación en formato canvas.

1. **No duplicar texto del MD.** Si la información ya está en el `.md` que el
   diagrama acompaña, no va también en el canvas. Prohibido en particular: tablas
   comparativas, advertencias largas, listados completos de campos, párrafos
   explicativos.
2. **Etiquetas mínimas**: nombre de la entidad + 2-4 campos clave, los que hacen
   falta para entender la relación con las otras cajas. El detalle va en el MD.
3. **Lo que sí lleva**: estructura (cajas y grupos con background de 25–30% de
   opacidad, con label arriba a la izquierda), relaciones (flechas
   **preferentemente curvas**, `roundness: { "type": 2 }` con puntos intermedios) y
   cardinalidades cortas (`1:1`, `1:N`, `N:1`, `M2M`).
4. **Cero bloques de texto largos** dentro del canvas.
5. **Precedente canónico**: `docs/domain/mapa-dominio.excalidraw.md`.

## Cuándo crear uno

Solo cuando aporta algo que el texto no comunica igual de rápido: estructura
espacial, relaciones cruzadas, jerarquía visual.

**Si el diagrama termina siendo "el MD pero en cajas", no lo hagas.** Un diagrama
redundante envejece peor que el texto, porque nadie lo actualiza cuando cambia la
decisión que ilustraba.

## Quién dibuja

**Dibujá el diagrama cuando tengas contexto suficiente.** Generá las cajas, flechas
y grupos con la información que ya está en el vault; el humano después mueve y
ajusta la estética en Obsidian.

Un borrador imperfecto vale más que un canvas vacío — el vacío no lo puebla nadie.
