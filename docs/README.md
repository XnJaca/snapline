---
id: HOME
title: "Snapline — Home"
type: home
tags:
  - home
---

# Snapline — Documentación

Vault de Obsidian de Snapline. Acá vive el **pensamiento del producto**, no el código.
El código vive en `../apps/`; los tipos compartidos en `../packages/contracts/`.

## Mapas del conocimiento

### Producto — el porqué y el qué

- [[product/vision|Visión]] — tesis, los cinco frentes y **"Qué NO somos"**, el gate duro
- [[product/roadmap|Roadmap]] — orden de construcción y lo descartado
- [[DECISIONES]] — decisiones tomadas y estado comercial
- [[PENDIENTES]] — qué falta hacer, incluidas las llaves del `.env`
- [[NOMBRE]] — el nombre está en revisión; leer antes de registrar nada
- [[CHANGELOG]] — bitácora humana por fecha

### Diseño del dominio

- [[domain/README|Índice de agregados]] — reglas transversales y una ficha por agregado
- Plantilla: `domain/0000-template.md`

### Decisiones arquitectónicas

- [[adr/README|Índice de ADRs]]
- Plantilla: `adr/0000-template.md`

### Specs de features

- [[specs/README|Índice de specs]] — lo que se va a implementar
- Boards: [[BOARD-specs-web]] · [[BOARD-specs-mobile]]

### Deuda técnica

- [[tech-debt/README|Índice de deuda técnica]] — decisiones postergadas a conciencia
- Board: [[BOARD-tech-debt]]

### Diagramas

- [[_diagrams/README|Convención de diagramas]] — dónde viven y qué va (y qué no) en un canvas
- [[domain/mapa-dominio.excalidraw|Mapa del dominio]] — los 13 agregados, navegable
- [[_diagrams/flujo-del-sistema.excalidraw|Flujo del sistema]] — recorrido de un trabajo por los cinco actores
- [[_diagrams/GUIA-JSON|Cheatsheet del JSON]] — para generarlos programáticamente

### Estado en vivo

- [[DASHBOARD]] — todo lo anterior en tablas que se actualizan solas

## Cómo trabajar acá

Los archivos nuevos se crean con slash commands desde Claude Code:

| Quiero… | Comando |
|---------|---------|
| Documentar una feature antes de codearla | `/spec-new <nombre>` |
| Capturar una decisión arquitectónica | `/adr-new <título>` |
| Definir un agregado del dominio | `/domain-new <agregado>` |
| Registrar deuda técnica consciente | `/debt-new <título>` |
| Crear un diagrama Excalidraw | `/diagram-new <nombre> [ubicación]` |
| **Revisar código antes del PR** | **`/review [spec]`** |
| Agregar entrada al changelog humano | `/changelog <descripción>` |
| Verificar si una idea entra al alcance | `/scope-check <idea>` |

## El goal y la revisión

Cada spec declara un **`goal`** en su frontmatter: una sola frase, en presente,
verificable leyendo código. No es decoración — es el ancla del ciclo entero.

```
goal del spec  →  se implementa  →  /review valida contra ese goal
```

El agente `code-reviewer` toma esa frase, la contrasta con lo que se escribió,
recorre las 30 reglas duras del `CLAUDE.md` y revisa la superficie de ataque real
del producto: aislamiento entre empresas, tokens del portal, escalada de
visibilidad de fotos, y los datos que manda el dispositivo — que son datos que
controla quien quiera manipularlos.

**Un goal vago deja al revisor sin trabajo posible.** Por eso `/spec-new` no deja
avanzar con "mejorar X" ni "implementar Y", y el [[DASHBOARD]] tiene una alerta
que los caza.

También se edita directo desde Obsidian — son archivos Markdown planos. Lo único
que hay que respetar es el frontmatter YAML: es lo que alimenta tags, queries y el grafo.

## Tags

- `#spec/borrador` · `#spec/aprobado` · `#spec/implementado`
- `#adr/propuesto` · `#adr/aceptado` · `#adr/supersedido`
- `#domain/borrador` · `#domain/estable`
- `#tech-debt/backlog` · `#tech-debt/activa`

## Los cinco frentes

Todo spec declara a cuál pertenece, en el campo `frente` del frontmatter:

| Frente | Qué cubre |
|---|---|
| `administrativo` | Proyectos, clientes, cuadrillas, catálogo, estimados, facturas |
| `campo` | Asistencia con geocerca, captura de fotos, offline |
| `cliente` | Portal, visibilidad del avance, venta cruzada |
| `reportes` | Timesheets, acceso del contador, costo por proyecto |
| `publicidad` | Publicación a la web, antes/después, contenido de redes, reseñas |

## Flujo

```
1. Visión y alcance          (product/vision)
       ↓
2. Agregados del dominio     (/domain-new)
       ↓
3. Spec de feature           (/spec-new)
       ↓
4. Decisiones grandes        (/adr-new cuando aplique)
       ↓
5. Implementar               (Claude Code en ../api ../web ../mobile)
       ↓
6. Changelog                 (/changelog)
```

## Setup

Ver [[OBSIDIAN_SETUP]]. Se abre `snapline/docs/` como vault; el resto del repo
no se ve desde Obsidian, y eso es a propósito: Obsidian para pensar, IDE para codear.
