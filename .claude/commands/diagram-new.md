---
name: diagram-new
description: Crea un diagrama Excalidraw nuevo, co-localizado con el doc que ilustra
allowed-tools: Read, Write, Edit, Glob, Bash(ls:*), Bash(test:*)
---

# /diagram-new

Crea un `.excalidraw.md` siguiendo la convención de `docs/_diagrams/README.md`.

## Uso

```
/diagram-new <nombre> [ubicación]
```

- `<nombre>` — kebab-case, sin extensión
- `[ubicación]` — carpeta relativa a `docs/`. Si se omite, `_diagrams/`

Ejemplos:

```
/diagram-new mapa-dominio domain
/diagram-new arquitectura-general _diagrams
/diagram-new flujo-facturacion specs/web/0007-facturacion
```

Argumentos recibidos: $ARGUMENTS

## Pasos

1. **Parsear.** Primer token = nombre, segundo (opcional) = ubicación. Default `_diagrams`.

2. **Validar que no exista** `docs/<ubicación>/<nombre>.excalidraw.md`. Si existe,
   abortá y avisá — no sobrescribas un diagrama.

3. **Validar la ubicación.** Debe ser `_diagrams`, `domain`, `specs`, `adr`,
   `product`, o una subcarpeta existente de `docs/`. Si es otra, confirmá antes.

4. **Decidir si el diagrama debe existir.** Antes de crear el archivo, preguntate
   qué aporta que el texto no comunique igual de rápido. Si la respuesta es "es lo
   mismo pero en cajas", **decilo y no lo crees**. Es la regla que evita llenar el
   vault de diagramas que nadie mantiene.

5. **Crear el archivo** con este contenido exacto, sin comprimir:

````markdown
---
excalidraw-plugin: parsed
tags:
  - excalidraw
  - diagram
---
==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==


# Text Elements

<Título humano> ^title


# Embedded Files


%%
# Drawing
```json
{
	"type": "excalidraw",
	"version": 2,
	"source": "https://github.com/zsviczian/obsidian-excalidraw-plugin",
	"elements": [
		{
			"type": "text",
			"version": 1,
			"versionNonce": 100000001,
			"isDeleted": false,
			"id": "title-<nombre>",
			"fillStyle": "solid",
			"strokeWidth": 2,
			"strokeStyle": "solid",
			"roughness": 1,
			"opacity": 100,
			"angle": 0,
			"x": -200,
			"y": -240,
			"strokeColor": "#1e1e1e",
			"backgroundColor": "transparent",
			"width": 400,
			"height": 36,
			"seed": 1,
			"groupIds": [],
			"frameId": null,
			"roundness": null,
			"boundElements": [],
			"updated": 1,
			"link": null,
			"locked": false,
			"fontSize": 28,
			"fontFamily": 1,
			"text": "<Título humano>",
			"textAlign": "center",
			"verticalAlign": "top",
			"containerId": null,
			"originalText": "<Título humano>",
			"lineHeight": 1.25,
			"baseline": 25
		}
	],
	"appState": {
		"gridSize": 20,
		"gridStep": 5,
		"gridModeEnabled": false,
		"viewBackgroundColor": "#ffffff"
	},
	"files": {}
}
```
%%
````

   El título humano se deriva del nombre: `mapa-dominio` → "Mapa del dominio".

6. **Dibujalo, no lo dejes vacío.** Si hay información suficiente en el vault
   (`docs/domain/`, el spec, el ADR), generá las cajas, grupos y flechas. Seguí
   `docs/_diagrams/GUIA-JSON.md` para la estructura de cada elemento.

   Un borrador imperfecto vale más que un canvas en blanco: el vacío no lo puebla
   nadie. Solo dejá el título solo si de verdad no hay contexto.

   Respetá las reglas duras de contenido: etiquetas mínimas, grupos con background
   de baja opacidad, flechas curvas con cardinalidades, **cero texto duplicado
   del MD**.

7. **Ofrecé embeberlo** en el doc que ilustra, con `![[<nombre>.excalidraw]]`.

8. **Si el diagrama es de dominio**, recordá que el mapa canónico es
   `docs/domain/mapa-dominio.excalidraw.md` — quizá lo que hace falta es agregarle
   una caja, no crear un diagrama nuevo.

9. **Reportá** dónde quedó, cómo abrirlo (Obsidian, vista Excalidraw) y cómo
   embeberlo.
