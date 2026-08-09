---
id: OBSIDIAN_SETUP
title: "Setup de Obsidian para Snapline"
type: guide
tags:
  - setup
  - obsidian
---

# Setup de Obsidian para Snapline

## Abrir el vault

1. Descargar Obsidian: https://obsidian.md
2. **"Open folder as vault"**
3. Seleccionar `snapline/docs/` — no la raíz del repo
4. Obsidian lee la config ya versionada en `.obsidian/`

El vault ya viene con core plugins activados, grafo con colores por tipo de
documento, y los archivos nuevos van a `specs/` por default.

## Plugins de la comunidad

No vienen preinstalados y hay que instalarlos a mano en cada máquina:
**Settings → Community plugins → Browse**, buscar, Install y Enable.

> **`.obsidian/community-plugins.json` no sirve para pedir plugins.** Ese archivo
> lo **reescribe Obsidian** con lo que está realmente instalado, así que listar algo
> ahí no lo instala — y al primer arranque se sobrescribe con la lista real. La
> fuente de verdad de qué hace falta es esta guía, no ese archivo.

Los tres primeros no son opcionales: sin ellos el vault se ve roto, no incompleto.

### 1. Dataview — obligatorio

Sin esto, [[DASHBOARD]] y todos los índices se ven como bloques de código en vez
de tablas. Es lo que convierte el vault en una base de datos consultable.

Busca: **Dataview** por Michael Brenan.

### 2. Kanban — obligatorio

Los tres BOARD son tableros Kanban. Sin el plugin se ven como listas de markdown.
Con él, arrastrás la tarjeta y se mueve el estado.

Busca: **Kanban** por mgmeyers.

### 3. Front Matter Title — obligatorio en la práctica

Los specs y los ADRs viven en `NNNN-slug/README.md`. Hoy ya hay **15 archivos
llamados `README.md`**, y crece uno por cada spec y cada ADR nuevo. Sin este plugin
la sidebar y el buscador muestran quince "README" idénticos; con él muestran el
alias del frontmatter.

Busca: **Front Matter Title** por Snezhig.

### 4. Excalidraw — obligatorio si vas a ver diagramas

Sin él, `mapa-dominio.excalidraw.md` y `flujo-del-sistema.excalidraw.md` son
archivos inertes.

**Al instalarlo, dos ajustes en sus settings:**

- **Compresión desactivada** (`compress: false`). Con compresión activada los
  diagramas se guardan como base64 y dejan de poder leerse o editarse fuera de
  Obsidian — que es exactamente cómo se generaron los dos que existen.
- **Carpeta por defecto**: `_diagrams/`.

Los diagramas se embeben en cualquier nota con `![[nombre.excalidraw]]`, y Cmd+click
en una caja con `link` te lleva al doc enlazado. Convención completa en
[[_diagrams/README|_diagrams/]].

## Opcionales de verdad

### 5. Obsidian Git — opcional

Commitear desde Obsidian sin saltar a la terminal. Útil en sesiones de solo escribir
specs, sin tocar código.

### 6. Advanced Tables — opcional

Estos docs tienen muchas tablas markdown. Si las vas a editar a mano desde Obsidian,
este plugin te alinea las columnas solo. Si solo las leés, no hace falta.

**Templater no hace falta.** Los archivos se crean con los slash commands de Claude
Code. Solo sirve si querés crear specs desde Obsidian sin pasar por la terminal.

## Dos modos de trabajo

**Pensar** — abrir Obsidian en `docs/`, editar visión, specs, dominio. Commitear
desde el plugin de Git o desde la terminal.

**Codear** — abrir terminal en la raíz `snapline/`, correr `claude`, usar los slash
commands. Los archivos aparecen en Obsidian al instante si lo tenés abierto.

El vault solo ve `docs/`. Es intencional: Obsidian para pensar, IDE para codear.

## Notas

- No editar `.obsidian/workspace.json` a mano — lo regenera Obsidian y está fuera de git.
- El frontmatter YAML es sensible a la indentación: las listas llevan dos espacios
  antes del `-`.
