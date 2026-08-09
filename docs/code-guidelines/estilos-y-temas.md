---
id: GUIDE-estilos
title: "Estilos y temas"
type: guide
tags:
  - guide
  - ui
---

# Estilos y temas

Reglas 21, 22 y 23 del `CLAUDE.md` raíz, con el detalle de cómo se cumplen.

## 1. Tres archivos, siempre

Todo componente de Angular son tres archivos separados:

```
project-card/
├── project-card.component.ts      lógica
├── project-card.component.html    estructura
└── project-card.component.scss    estilos
```

```ts
// ✅
@Component({
  selector: 'sl-project-card',
  templateUrl: './project-card.component.html',
  styleUrls: ['./project-card.component.scss'],
})
export class ProjectCardComponent {}
```

```ts
// ❌ nunca — ni "porque es chiquito"
@Component({
  selector: 'sl-project-card',
  template: `<div class="card">{{ project.name }}</div>`,
  styles: [`.card { padding: 16px; background: #fff; }`],
})
```

**Por qué.** Un estilo dentro del `.ts` no se puede buscar con las herramientas de
CSS, no lo ve el linter de estilos, y no se puede extraer cuando el patrón se
repite en otros cinco componentes. En ACDEMIC esto se dejó pasar por componentes
chicos y hoy los estilos están desperdigados dentro de la lógica. El componente
chiquito es justamente el que crece.

Esto aplica también al archivo de test y al de i18n si los hubiera: un archivo,
una responsabilidad.

## 2. Tres capas de tokens

Los valores viven en **`design-tokens.json`** en la raíz del monorepo, que es la
fuente única para las tres superficies. Ver [[../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]].
Los snippets de abajo muestran la forma que toman en CSS; los hex salen de ahí.

El componente nunca ve un color. Ve un token semántico.

```
Primitivas          →   Semánticos           →   Componente
--sl-orange-700         --sl-color-primary       var(--sl-color-primary)
--sl-neutral-100        --sl-color-surface
--sl-space-4            --sl-color-danger
```

**Primitivas** — la paleta cruda. No se usan directamente en ningún componente.

Los neutros son de **gris puro** (`neutral`), sin tinte: `slate` tira a azul y hace
ver azuladas las fotos de obra; `stone` tira a cálido y en fondos oscuros se lee
como café. El calor lo pone el naranja, no los grises.

```scss
// styles/tokens/_primitives.scss
:root {
  --sl-orange-700:  #c2410c;
  --sl-neutral-050: #fafafa;
  --sl-neutral-900: #171717;
  --sl-neutral-950: #0a0a0a;

  --sl-space-1: 4px;
  --sl-space-2: 8px;
  --sl-space-3: 12px;
  --sl-space-4: 16px;

  --sl-radius-sm: 4px;
  --sl-radius-md: 8px;

  --sl-font-size-body: 16px;
  --sl-font-size-title: 20px;
}
```

**Semánticos** — qué significa cada color en la interfaz. Esta capa es la que cambia
entre tema claro y oscuro.

```scss
// styles/tokens/_semantic.scss
:root,
[data-theme='light'] {
  --sl-color-primary:            var(--sl-orange-700);
  --sl-color-primary-container:  #ffedd5;
  --sl-color-surface:            #ffffff;
  --sl-color-background:         var(--sl-neutral-050);
  --sl-color-text:               var(--sl-neutral-900);
  --sl-color-text-muted:         #525252;
  --sl-color-border:             #e5e5e5;
  --sl-color-danger:             #dc2626;
  --sl-color-danger-container:   #fee2e2;
  --sl-color-warning:            #a16207;   // banderas de asistencia
  --sl-color-warning-container:  #fef9c3;
  --sl-color-success:            #15803d;
  --sl-color-success-container:  #dcfce7;
}

[data-theme='dark'] {
  --sl-color-primary:            #fb923c;
  --sl-color-primary-container:  #7c2d12;
  --sl-color-surface:            #171717;
  --sl-color-background:         var(--sl-neutral-950);
  --sl-color-text:               #fafafa;
  --sl-color-text-muted:         #a3a3a3;
  --sl-color-border:             #404040;
  --sl-color-danger:             #f87171;
  --sl-color-danger-container:   #7f1d1d;
  --sl-color-warning:            #facc15;
  --sl-color-warning-container:  #713f12;
  --sl-color-success:            #4ade80;
  --sl-color-success-container:  #14532d;
}
```

### La regla que hace falta saber antes de usar estos tokens

Naranja, ámbar y rojo viven en 35 grados de rueda: **el tono no alcanza para
distinguirlos**. La separación la da la forma.

- El **naranja saturado es solo de la acción primaria**. Un botón sólido por
  pantalla. Si dos cosas son naranjas, ninguna es la acción.
- Los **estados van siempre en su variante `container`** —fondo tenue, texto
  oscuro, icono— nunca en relleno sólido.
- **Ningún estado se comunica solo con color.** El icono es obligatorio.

**Componente** — solo consume.

```scss
// project-card.component.scss
.card {
  background: var(--sl-color-surface);
  color: var(--sl-color-text);
  border: 1px solid var(--sl-color-border);
  border-radius: var(--sl-radius-md);
  padding: var(--sl-space-4);
}
```

**Un valor literal en el archivo de un componente es un error de revisión.**
Cero excepciones para colores. Si el token que hace falta no existe, se agrega
a la capa semántica — no se hardcodea y se sigue, porque eso es exactamente cómo
se acumula el desorden.

## 3. Los dos temas, desde el primer componente

El tema se aplica con `data-theme` en el `<html>`, y el default respeta la
preferencia del sistema:

```ts
// theme.service.ts
type Theme = 'light' | 'dark' | 'system';

setTheme(theme: Theme): void {
  const resolved = theme === 'system'
    ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
    : theme;
  document.documentElement.setAttribute('data-theme', resolved);
}
```

**Por qué importa en este producto y no es cosmético.** La misma app se usa en un
techo con sol directo y en un sótano sin luz. El tema no es una preferencia
estética del usuario, es legibilidad en condiciones reales de uso.

Consecuencia práctica: el contraste de texto sobre fondo debe cumplir **WCAG AA
(4.5:1)** en los dos temas. Un gris clarito que se ve elegante en el monitor es
invisible en una pantalla al sol.

Un componente que solo se probó en claro está sin terminar.

## 4. Flutter — la misma regla, otra sintaxis

Los widgets no llevan valores de estilo literales. Consumen el tema.

```dart
// ❌
Container(
  padding: const EdgeInsets.all(16),
  color: const Color(0xFF1D4ED8),
  child: Text('Marcar entrada', style: TextStyle(fontSize: 16, color: Colors.white)),
)

// ✅
Container(
  padding: EdgeInsets.all(context.spacing.md),
  color: Theme.of(context).colorScheme.primary,
  child: Text(l10n.clockIn, style: Theme.of(context).textTheme.bodyLarge),
)
```

`ThemeData` se define una vez con `ColorScheme.light` y `ColorScheme.dark`, y los
tokens que Material no cubre (espaciado, radios propios) van en un
`ThemeExtension`. La app declara `theme`, `darkTheme` y `themeMode` desde el
primer commit — no se agrega dark mode después.

## 5. Qué revisar antes de aprobar un cambio de UI

- [ ] ¿El componente tiene sus tres archivos separados?
- [ ] ¿Hay algún color, tamaño o espaciado literal en el `.scss` del componente?
- [ ] ¿Se ve bien en claro **y** en oscuro?
- [ ] ¿El contraste pasa AA en los dos temas?
- [ ] ¿Los tokens nuevos se agregaron a la capa semántica, no al componente?
- [ ] ¿Hay algún texto quemado? (ver [[i18n]])

## Pendiente

- [x] ~~**ADR de sistema de diseño**~~ — resuelto en
      [[../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] el 2026-08-08:
      `design-tokens.json` en la raíz, Material 3 nativo en Flutter sin librería
      de componentes, y `ColorScheme` explícito en vez de `ColorScheme.fromSeed`.
- [ ] **Librería de componentes para Angular** — se decide cuando arranque
      `apps/web`, en su propio ADR. Cualquiera que se adopte consume los tokens
      del JSON, no los suyos.
