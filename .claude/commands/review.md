---
name: review
description: Revisa el código de la rama actual contra el goal del spec, las reglas duras y la superficie de ataque de Snapline
allowed-tools: Read, Grep, Glob, Bash, Agent
---

Revisá el código escrito antes de abrir el PR.

Argumento recibido: $ARGUMENTS — puede ser un número de spec, una ruta, o vacío
(en cuyo caso se revisa el diff de la rama actual contra `main`).

## Pasos

1. Determiná el alcance:
   - Con argumento de spec (`0007`, `SPEC-0007`, `M0003`) → buscá el spec y su rama.
   - Con rutas → revisá esos archivos.
   - Sin argumento → `git diff main...HEAD --stat` para ver qué cambió, y deducí
     el spec desde el nombre de la rama (`feature/SPEC-XXXX-slug`).

2. Si no hay nada que revisar, decilo y terminá. No inventes una revisión.

3. Invocá al agente `code-reviewer` pasándole:
   - la ruta del spec (o el aviso de que no hay spec)
   - la lista de archivos cambiados
   - el diff

4. Mostrá el reporte del agente **tal cual**. No lo resumas ni lo suavices.

5. Después del reporte:
   - Si hay hallazgos **GRAVES**, no abras el PR. Decilo explícitamente.
   - Preguntá si querés que aplique los arreglos, o si los revisás primero.
   - Si un hallazgo se decide postergar a conciencia, eso es `/debt-new`, no un
     TODO en el código.

6. Si la revisión pasa y el spec tiene todos sus criterios cumplidos, recordá mover
   el spec en el BOARD y actualizar su `status` — los dos en el mismo acto (regla 3).

No mergees el PR. Nunca.
