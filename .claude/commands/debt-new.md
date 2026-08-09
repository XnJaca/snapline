---
name: debt-new
description: Registra deuda técnica consciente en docs/tech-debt/
allowed-tools: Read, Write, Glob, Bash, Edit
---

Vas a registrar deuda técnica de Snapline.

Argumento recibido: $ARGUMENTS

## Pasos

1. Leé `docs/tech-debt/0000-template.md`.

2. **Verificá que sea deuda técnica.** No lo es:
   - un bug → es un ticket
   - una feature del roadmap → va a `docs/specs/`
   - un TODO local de implementación → vive en el código

   Sí lo es: un atajo arquitectónico tomado a conciencia, un endpoint sin UI, una
   validación que hoy se hace a mano, un caso borde sin cubrir.

3. Número secuencial en `docs/tech-debt/`, archivo `NNNN-slug.md`.
   Fecha con `date +%Y-%m-%d`.

4. **El `trigger` es obligatorio y no puede ser vago.** "Cuando haya tiempo" no es
   trigger. "Cuando entre el segundo cliente" sí. Sin trigger concreto la deuda
   queda olvidada para siempre, que es exactamente lo que esta carpeta evita.

5. El `workaround actual` explica por qué es vivible hoy. Si no hay workaround,
   probablemente no es deuda: es algo roto.

6. Movelo al `docs/BOARD-tech-debt.md` en la columna Backlog, en el mismo acto.
