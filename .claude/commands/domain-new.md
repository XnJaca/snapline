---
name: domain-new
description: Crea la ficha de un agregado del dominio en docs/domain/
allowed-tools: Read, Write, Glob, Bash, Edit
---

Vas a documentar un agregado del dominio de Snapline.

Argumento recibido: $ARGUMENTS

## Pasos

1. Leé `docs/domain/0000-template.md` y `docs/domain/`.

2. **Chequeá que no exista ya.** `docs/domain/README.md` tiene la versión narrativa de
   casi todos los agregados; si el que se pide ya está ahí, la ficha se **deriva**
   de ese texto, no se reinventa. Si hay contradicción, gana `docs/domain/README.md` y
   se avisa.

3. Archivo en `docs/domain/<slug>.md`. Fecha con `date +%Y-%m-%d`.

4. Las secciones que hacen el trabajo son **Invariantes** y **Qué NO es**. Un
   agregado sin invariantes declaradas está a medias.

   Recordá que las reglas transversales ya aplican a todos y no se repiten en cada
   ficha: `company_id`, UUIDv7 del cliente, dinero en centavos, doble marca de
   tiempo, borrado suave, escrituras idempotentes.

5. **Comportamiento offline es obligatorio** si el agregado se crea o modifica desde
   el móvil: qué genera el dispositivo, cómo se resuelve un conflicto, y si lo
   resuelve el sistema o un humano.

6. Enlazá con `[[wikilinks]]` los agregados relacionados, aunque todavía no existan
   — un link roto marca lo que falta escribir.

7. **Agregá su caja al mapa canónico**, en el mismo acto:
   `docs/domain/mapa-dominio.excalidraw.md`.

   - Ubicala en la zona que le corresponde (tenencia, obra, campo, comercial,
     cliente final, publicación), o creá una zona nueva si no encaja en ninguna.
   - La caja lleva `"link": "[[slug|Nombre]]"` para que el mapa sea navegable.
   - Etiqueta mínima: nombre + 2-4 campos clave. **Nada más** — el detalle vive en
     la ficha, no en el canvas. Ver `docs/_diagrams/GUIA-JSON.md`.
   - Agregá también las flechas de sus relaciones principales, con cardinalidad.

   La posición exacta la ajusta el humano en Obsidian; tu trabajo es que la caja
   exista y esté conectada. **Un agregado que no está en el mapa es un agregado que
   nadie ve.**
