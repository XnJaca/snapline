---
id: ADR-0015
title: "Contexto de diseño para agentes: PRODUCT.md y DESIGN.md"
aliases:
  - "ADR-0015: Contexto de diseño para agentes"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: ["SPEC-0010"]
created: 2026-09-05
updated: 2026-09-05
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
  - ui
---

# ADR-0015: Contexto de diseño para agentes

> **Meta**
> - Deciders: @jaca
>
> _Estado y fecha viven en el frontmatter arriba — no duplicar aquí._

## Contexto

El panel se construyó con el sistema de tokens de
[[../0009-sistema-de-diseno-y-tokens/README|ADR-0009]] y las reglas de UI del
`CLAUDE.md`, y aun así el resultado se veía mal. La revisión del 2026-09-04 dio
el diagnóstico: **el sistema estaba a medias y nadie podía notarlo**. Faltaban los
tokens de interlineado, el atajo compuesto de Material contradecía a sus propias
piezas, y el modo claro no tenía superficies perceptibles (ΔL\* 1.7). Ninguna de
las tres cosas viola una regla escrita.

Detrás de eso hay un hueco más difícil de ver. La guía de estilos dice **cómo** se
escribe el CSS; `design-tokens.json` dice **qué valores** existen. Ninguno de los
dos dice **para quién es esto, qué personalidad tiene, ni a qué no se tiene que
parecer**. Sin eso, cada sesión vuelve a decidir el tono desde cero, y la
decisión que sale es el default: un panel que se parece a QuickBooks.

La restricción concreta que obliga a decidirlo ahora: las skills de diseño
—`impeccable` y las demás— **se bloquean sin `PRODUCT.md`**, y sus comandos de
crítica y pulido leen `DESIGN.md` antes de trabajar. Sin los dos archivos, la
mitad de las herramientas disponibles no corre.

## Decisión

**`PRODUCT.md` y `DESIGN.md` viven en la raíz del repo, versionados, y son
contexto de lectura obligatoria antes de tocar la interfaz.**

- **`PRODUCT.md`** responde quién / qué / por qué: register, usuarios, propósito,
  personalidad, **anti-referencias** y principios de diseño. No lleva ni un valor
  visual.
- **`DESIGN.md`** responde cómo se ve: paleta, tipografía, elevación, componentes
  y sus do's and don'ts, en el formato DESIGN.md de Stitch para que lo lea
  cualquier herramienta que lo entienda.

**`design-tokens.json` sigue siendo la fuente única de los valores.** `DESIGN.md`
es su espejo y lo declara en su propio texto: cuando divergen, manda el JSON.

Van en la raíz y no en `docs/` porque son del mismo tipo que `CLAUDE.md` —
contexto que se lee antes de trabajar, no documentación que se consulta— y porque
es donde las herramientas los buscan primero.

## Alternativas consideradas

### Alternativa A — No tenerlos: que alcancen el `CLAUDE.md` y la guía de estilos

Es lo que había, y produjo el resultado que motivó este ADR. Las reglas de UI
cubren el cómo con precisión, pero **no hay dónde escribir que esto no se tiene
que parecer a QuickBooks**, ni que la personalidad es "herramienta de trabajo,
sobria, rápida". Sin anti-referencias declaradas, cada sesión las infiere, y lo
que se infiere de "software para contratistas" es exactamente el software que no
queremos.

Además deja fuera la mitad de las herramientas: sin `PRODUCT.md` las skills de
diseño no arrancan.

### Alternativa B — Ponerlos bajo `docs/`

Encajaría con el resto de la documentación y con la regla 28 del DASHBOARD. Pero
estos dos no son documentación de consulta: son **contexto de entrada**, como el
`CLAUDE.md`, que tampoco vive en `docs/`. Enterrarlos entre veinte archivos de
docs es garantizar que no se lean antes de escribir CSS, que es justo el momento
en que hacen falta.

### Alternativa C — Generar `DESIGN.md` desde `design-tokens.json`

Elimina de raíz el riesgo de desincronización. Se descartó porque **el valor de
`DESIGN.md` no son los valores**: esos ya están en el JSON y en el SCSS generado.
Lo que aporta es la prosa que explica cuándo usar cada uno — que el naranja
saturado es solo de la acción primaria, que los estados van en su variante
`container`, que la separación se hace con bordes y no con sombras. Un generador
produciría la tabla de colores y perdería exactamente lo que hace falta.

## Consecuencias

### Positivas

- Las skills de diseño corren, y con contexto del producto en vez de genérico.
- Las anti-referencias quedan escritas y son verificables en una revisión: "esto
  se parece a un SaaS de plantilla" pasa a ser un hallazgo, no una opinión.
- Una sesión nueva no vuelve a decidir el tono. La decisión ya está tomada.
- `PRODUCT.md` obliga a nombrar la personalidad. Al escribirlo apareció el
  principio que faltaba: **densidad con jerarquía, no densidad plana**, que es
  exactamente lo que estaba fallando.

### Negativas / Costos

- **Dos archivos más que mantener a mano**, y uno de ellos duplica valores que ya
  viven en `design-tokens.json`.
- **La duplicación ya se rompió el día uno**: `DESIGN.md` se creó declarando el
  fondo claro en `#FAFAFA` mientras el mismo cambio lo llevaba a `#F4F4F5`. Lo
  cazó `code-reviewer`, no una persona.
- El formato de `DESIGN.md` lo define una herramienta externa (Stitch). Si cambia
  su especificación, el archivo queda desactualizado sin que nada avise.

### Riesgos

- **Que `DESIGN.md` derive de los tokens y nadie lo note.** Se mitiga con la
  jerarquía declarada —el JSON manda— y con un ítem en la checklist de revisión
  de UI. El chequeo es mecánico: comparar los roles del frontmatter contra
  `design-tokens.json`.
- **Que `PRODUCT.md` contradiga a `docs/product/vision.md`.** La visión es la
  fuente; `PRODUCT.md` la resume para una herramienta. Si se contradicen, gana la
  visión, igual que con `DECISIONES.md`.

## Qué lo revierte

- Que aparezca una forma de generar `DESIGN.md` desde los tokens **sin perder la
  prosa** — por ejemplo, tokens que admitan una descripción por rol. Ahí la
  alternativa C pasa a ser la correcta.
- Que las herramientas dejen de pedir estos archivos, o que el proyecto deje de
  construir interfaz con agentes.

## Impacto en el modelo

Ninguno: no toca agregados, esquema ni contrato.

- [[../../specs/web/0010-obras-en-el-panel/README|SPEC-0010]] — la pasada de
  diseño que los originó

## Referencias

- [[../0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — `design-tokens.json`
  como fuente única, que este ADR no cambia
- [[../0013-componentes-angular-material/README|ADR-0013]] — Material recibe los
  tokens en vez de derivarlos
- `docs/code-guidelines/estilos-y-temas.md` — el cómo, que estos dos no repiten
- Formato de `DESIGN.md`: https://stitch.withgoogle.com/docs/design-md/format/
