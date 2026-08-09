---
name: adr-new
description: Crea un ADR en docs/adr/ desde la plantilla, con frontmatter listo para Obsidian
allowed-tools: Read, Write, Glob, Bash, Edit
---

Vas a crear un ADR (registro de decisión arquitectónica) para Snapline.

Argumento recibido: $ARGUMENTS

## Pasos

1. Leé `docs/adr/0000-template.md`.

2. **Verificá que sea un ADR.** Si la decisión se revierte en una tarde, no lo es —
   decilo y proponé dónde va (spec, deuda técnica, o simplemente hacerlo).

   Sí es ADR: stack, librerías principales, patrones de seguridad, estrategia de
   deploy, cambios estructurales del modelo, decisiones que atan a un proveedor.

3. Número secuencial en `docs/adr/`, padding de 4 dígitos. Archivo en
   `docs/adr/NNNN-slug/README.md`. Fecha con `date +%Y-%m-%d`.

4. Frontmatter con `type: adr`, `aliases`, `status: propuesto`, `deciders: [jaca]`.

5. **Llenalo conversando.** El valor de un ADR está en las alternativas y en el
   costo, no en la decisión. Preguntá:
   - ¿Qué restricción concreta obliga a decidir esto ahora?
   - ¿Qué alternativas reales hay? (mínimo dos, con por qué no)
   - ¿Qué se cede al elegir esta? Un ADR sin costos declarados está mal escrito.
   - ¿Qué lo revierte? Qué tendría que pasar para superseder este ADR.

6. Si supersede a otro ADR, actualizá el `superseded_by` del viejo en el mismo acto.

7. Enlazá los agregados y specs impactados con `[[wikilinks]]`.
