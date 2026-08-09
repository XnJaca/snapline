---
name: changelog
description: Agrega una entrada al changelog humano de docs/CHANGELOG.md
allowed-tools: Read, Edit, Bash
---

Agregá una entrada a `docs/CHANGELOG.md`.

Argumento recibido: $ARGUMENTS

## Reglas

- El changelog es por **fecha** y registra **qué se decidió y por qué** — no qué
  archivos cambiaron. Eso ya está en git.
- Fecha de hoy con `date +%Y-%m-%d`. Si la sección de hoy existe, agregá el bullet;
  si no, creá la sección arriba de todo.
- Escribí desde el **efecto**, no desde el código. "El trabajador ya puede marcar
  entrada sin señal" y no "se agregó el campo recorded_offline".
- Enlazá con `[[wikilinks]]` los specs, ADRs o docs involucrados.
- Una entrada por decisión. Si el argumento trae tres cosas, son tres bullets.
