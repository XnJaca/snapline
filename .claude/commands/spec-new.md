---
name: spec-new
description: Crea un spec de feature en docs/specs/web/ o docs/specs/mobile/ desde la plantilla, con frontmatter listo para Obsidian
allowed-tools: Read, Write, Glob, Bash, Edit
---

Vas a crear un spec de feature para Snapline.

Argumento recibido: $ARGUMENTS

## Pasos

1. Leé `docs/specs/0000-template.md`.

2. **Preguntá la plataforma primero**:
   > "¿Este spec es para **web** (api, admin Angular, sitio Astro) o para **mobile** (Flutter)?"

   - web → `docs/specs/web/NNNN-slug/README.md`
   - mobile → `docs/specs/mobile/NNNN-slug/README.md`

3. Determiná el siguiente número secuencial en la carpeta correspondiente,
   ignorando `README.md` y `0000-template.md`. Padding de 4 dígitos.

4. **Ubicá la feature antes de escribir nada**:
   - Leé `docs/product/vision.md`. La sección **"Qué NO somos"** es el único gate
     duro: si la feature lo contradice, DETENTE y señalá la contradicción.
   - Identificá a cuál de los cinco frentes pertenece: `administrativo`, `campo`,
     `cliente`, `reportes`, `publicidad`. Va en el frontmatter.
   - Leé `docs/domain/README.md` y las fichas para saber qué agregados toca. Si introduce uno
     nuevo, documentalo primero con `/domain-new`.

5. **El `goal` es lo primero que se define y no puede quedar en TODO.**

   Una sola frase, en presente, verificable leyendo código. Es contra lo que el
   agente `code-reviewer` valida después lo implementado, así que un goal vago
   deja al revisor sin trabajo posible.

   Preguntá: *"¿Qué tiene que ser cierto cuando esto esté terminado?"*

   Si la respuesta es "mejorar X", "implementar Y" o "agregar Z", no es un goal:
   repreguntá hasta tener algo que se pueda verificar. Bien: *"Una foto tomada sin
   señal se sube sola cuando vuelve la red, sin que el trabajador haga nada."*

6. **Frontmatter** — obligatorio `type: spec`, `aliases`, `status`, `goal`, `apps`,
   `frente` y `updated`. Sin `type: spec` el spec no aparece en el índice y nadie se entera.
   El alias es obligatorio porque todos los specs viven en `NNNN-slug/README.md` y
   sin él Obsidian muestra solo "README" en la sidebar.
   Fecha con `date +%Y-%m-%d`.

7. **Si `platform: mobile`**, la sección "Comportamiento sin señal" es obligatoria
   y no puede quedar en TODO. Funcionar sin señal es requisito no negociable
   (regla 9 del CLAUDE.md).

8. Movelo en el BOARD correspondiente: **Backlog → Borrador**, en el mismo acto.
   El índice de specs se genera solo con Dataview, así que no hay tabla que tocar.

9. **Modo interactivo**. Preguntá:
   > "Spec creado en `docs/specs/<plataforma>/NNNN-slug/README.md`.
   > ¿Lo llenamos ahora con preguntas, o lo dejás para después?"

   Si dice que sí:
   a. Cargá contexto: ADRs relacionados, specs de los que depende, agregados que toca.
   b. Preguntá **una por una**, de mayor a menor impacto. No tires varias juntas.
   c. Si dice "no sé", proponé un default con su trade-off en una línea y seguí.
   d. Si aparece una decisión arquitectónica grande, sugerí `/adr-new` en vez de
      meterla al spec.
   e. Al final escribí directo al archivo. No pegues el spec completo en el chat —
      se revisa en Obsidian.

NO implementes código de la feature. El spec es el paso previo.
