---
id: ADR-0013
title: "Angular Material y CDK para el panel, con los tokens del JSON por theme-overrides"
aliases:
  - "ADR-0013: Angular Material y CDK para el panel, con los tokens del JSON por theme-overrides"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs:
  - SPEC-0007
created: 2026-08-30
updated: 2026-09-01
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
  - ui
---

# ADR-0013: Angular Material y CDK para el panel, con los tokens del JSON por theme-overrides

> **Meta**
> - Deciders: @jaca
>
> _Estado y fecha viven en el frontmatter arriba — no duplicar aquí._

## Contexto

[[../0009-sistema-de-diseno-y-tokens/README|ADR-0009]] §4 dejó esta decisión abierta
a propósito: *"la decisión para Angular queda abierta. Se toma cuando arranque
`apps/web`, en su propio ADR: las tablas densas de facturación tienen necesidades
que no se pueden evaluar sin haber escrito una pantalla."*

`apps/web` arranca ahora, con [[../../specs/web/0007-cimientos-visuales/README|SPEC-0007]].

Lo que hay que resolver no es "qué librería es mejor" en abstracto, sino no
reintroducir el problema que los dos ADRs anteriores ya trabajaron:

- [[../0002-superficies-flutter-angular/README|ADR-0002]] declaró el riesgo —deriva
  visual entre Angular y Flutter— con la mitigación enunciada pero sin mecanismo.
- ADR-0009 puso el mecanismo: `design-tokens.json` es la fuente única, y en Flutter
  se prohibió `ColorScheme.fromSeed` para declarar cada color explícitamente. Se
  cambió la armonización automática de Material 3 **por paridad exacta entre
  superficies**.

Una librería que traiga su propio sistema de theming vuelve a partir la fuente en
dos, y el trabajo de ADR-0009 se pierde el primer día de la segunda superficie.

Restricción del contexto: un solo desarrollador, y la fase que más componentes
densos necesita —facturación— ya está bloqueada por una conversación con el contador.
No conviene sumarle riesgo de calendario.

## Decisión

**Angular Material con el CDK, y ninguna otra librería de componentes.**

### 1. Los valores salen del JSON, nunca de la paleta que Material genera

Los tokens de `design-tokens.json` entran uno por uno con `mat.theme-overrides()`.
Es el espejo exacto de ADR-0009 §2: donde en Flutter se prohibió `fromSeed`, en web
se prohíbe quedarse con la paleta derivada de `mat.theme()`.

```scss
@include mat.theme-overrides((
  primary: #1d4ed8,   // el hex del JSON, no el que Material derivaría
  surface: #FAFAFA,
));
```

### 2. Los componentes consumen tokens, nunca valores

Material emite su tema como CSS custom properties (`--mat-sys-*`). Un componente
propio consume esas variables o las `--sl-*` nuestras. **Un hex literal en el
`.scss` de un componente sigue siendo error de revisión** (regla 22), sin cambios.

### 3. Lo que M3 no cubre vive aparte, igual que en Flutter

Los colores de bandera de asistencia y lo que no tiene lugar en el vocabulario M3
van como variables `--sl-*` propias, generadas del mismo JSON. En Flutter eso es un
`ThemeExtension` (ADR-0009 §3); acá son variables CSS. Misma fuente, dos formatos.

### 4. El CDK es la salida cuando Material no alcanza

Antes de traer otra librería se construye el componente propio sobre el CDK, que ya
viene incluido y aporta overlay, accesibilidad, virtual scroll y la tabla sin
estilos. Traer una segunda librería de componentes es una decisión que necesita su
propio ADR.

## Alternativas consideradas

### Alternativa A — Solo el CDK, todos los componentes propios

Control visual total, cero capa de theming ajena, y el diseño no se parece a nada.

**Por qué no:** la tabla de facturación se escribe entera, incluida su
accesibilidad y su comportamiento de teclado. Con un solo desarrollador, eso se paga
justo en la fase 3, que ya arrastra un bloqueo externo. La ganancia —no parecerse a
Material— no compensa ese riesgo hoy, y esta decisión se puede endurecer después:
ir de Material a componentes propios sobre CDK es incremental, componente por
componente.

### Alternativa B — PrimeNG

El catálogo más grande del ecosistema y la tabla más completa: filtros, export,
edición en celda, virtual scroll.

**Por qué no:** desde la v18 trae su propio sistema de design tokens (`--p-*`). Eso
es literalmente *"su propio sistema de theming encima del de Material, que es justo
la capa extra que el pendiente original señalaba como problema"* — las palabras de
ADR-0009 §4 sobre por qué Flutter no adoptó una librería. Y no tiene parentesco con
M3, así que la paridad contra Flutter habría que sostenerla a mano, token por token,
para siempre.

### Alternativa C — Tailwind con componentes headless

Utilidades y componentes sin estilo, máxima flexibilidad visual.

**Por qué no:** Tailwind trae su propia escala de espaciado, radios y color. Habría
dos sistemas de tokens conviviendo y `design-tokens.json` dejaría de ser la fuente
única. Peor: la regla 22 —*"un hex literal en el archivo de un componente es un
error de revisión"*— deja de ser verificable cuando el valor llega por una clase
utilitaria en el HTML en vez de por una variable en el SCSS.

## Consecuencias

### Positivas

- **Las dos superficies hablan el mismo vocabulario.** `primary`, `surface`,
  `on-surface-variant` significan lo mismo en el `ColorScheme` de Flutter y en los
  `--mat-sys-*` de Angular. El riesgo de ADR-0002 se mitiga por construcción, no por
  disciplina.
- **La regla 22 se cumple sola.** El tema de Material ya es variables CSS: consumir
  tokens es el camino de menor resistencia, no el que hay que recordar.
- La regla 23 —los dos temas desde el primer componente— sale de `color-scheme` y
  `light-dark()`, sin trabajo adicional.
- El CDK entra sin dependencia extra: overlay, a11y, drag & drop, virtual scroll.

### Negativas / Costos

- **El look de Material se nota.** El panel se va a parecer a una app de Google
  salvo que se trabaje encima. Se acepta a cambio de la paridad.
- Los overrides son verbosos: cada token se declara explícitamente, igual que en
  Flutter. Es el mismo costo que ADR-0009 §2 ya aceptó, ahora por duplicado.
- Angular Material tiene su propio ciclo de breaking changes en theming — la
  migración de M2 a M3 ya lo demostró.

### Riesgos

- **Que un token del JSON no tenga equivalente en M3.** Mitigación: la decisión 3 —
  lo que no cabe en el vocabulario de Material vive en variables `--sl-*` propias,
  generadas del mismo archivo.
- **Que alguien use la paleta derivada en vez del override**, y aparezca un color
  que en Flutter es otro. Mitigación: es error de revisión, igual que un hex literal.
  Un color del panel que no salga del JSON no pasa el review.

### Qué lo revierte

Que el panel necesite un datagrid que Material no da, y construirlo sobre el CDK
salga más caro que adoptar PrimeNG únicamente para esa pantalla. En ese caso se
escribe el ADR que supersede a este, con el costo de theming declarado.

## Impacto en el modelo

Ninguno. Es una decisión de superficie: no toca agregados, entidades ni contrato.

- [[../../specs/web/0007-cimientos-visuales/README|SPEC-0007: Cimientos visuales del panel]]
- [[../../tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001]] — el mismo spec la cierra,
  y esta decisión es la que le da un segundo consumidor al generador

## Referencias

- [[../0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — su §4 es lo que este ADR cierra
- [[../0002-superficies-flutter-angular/README|ADR-0002]] — el riesgo de deriva que motiva todo esto
- [[../../code-guidelines/estilos-y-temas|estilos-y-temas.md]] — las tres capas de tokens y las reglas 21 a 23
