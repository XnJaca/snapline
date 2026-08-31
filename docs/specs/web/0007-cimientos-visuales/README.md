---
id: SPEC-0007
title: "Cimientos visuales del panel"
aliases:
  - "SPEC-0007: Cimientos visuales del panel"
type: spec
platform: web
status: en-implementacion
goal: "El panel se ve en los dos temas y en los dos idiomas con los mismos colores que la app del teléfono, y ningún valor de diseño se copia a mano entre superficies."
apps:
  - web
  - mobile
depends_on: []
domain: []
frente: plataforma
created: 2026-08-30
updated: 2026-08-30
tags:
  - spec
  - spec/en-implementacion
  - web
  - ui
---

# SPEC-0007: Cimientos visuales del panel

> **Meta**
> - Apps afectadas: `web`, `mobile`
> - Depende de: —
> - Frente: `plataforma`
>
> `mobile` está en la lista porque el generador de tokens reescribe
> `apps/mobile/lib/core/theme/tokens.dart`, que hoy se mantiene a mano.
> **No toca el API.**

---

## Problema

`apps/web` no existe: no hay carpeta. Y antes de que exista una pantalla hay que
resolver de dónde saca sus colores, porque la respuesta condiciona todo lo que venga
después.

Hoy `design-tokens.json` tiene **un solo consumidor**. `apps/mobile/lib/core/theme/tokens.dart`
se escribe a mano copiando esos valores, y nada valida que los dos archivos
coincidan: se puede cambiar un color en el JSON y que la app siga compilando con el
valor viejo, sin ningún aviso. Eso es [[../../../tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001]],
y su `trigger` declarado es literalmente *"el scaffold de `apps/web`, cuando aparezca
el segundo consumidor de tokens"*.

Ese segundo consumidor es este spec. Con dos destinos copiados a mano, la deriva
visual que [[../../../adr/0002-superficies-flutter-angular/README|ADR-0002]] declaró
como riesgo deja de ser hipotética: **la misma foto de obra y el mismo estado de
bandera tienen que verse igual en el teléfono del trabajador y en el panel de
William**, y hoy nada lo garantiza más que la memoria de quien edita.

## Alcance

### Entra

- **Scaffold de Angular en `apps/web`**, agregado a `pnpm-workspace.yaml` y a los
  pipelines de `turbo` (`build`, `typecheck`, `lint`, `test`).
- **Style Dictionary generando desde `design-tokens.json`**: variables CSS para web
  y `tokens.dart` para Flutter. El JSON deja de copiarse a mano a ningún lado, y
  DEBT-0001 pasa a Resuelta.
- **Angular Material + CDK** ([[../../../adr/0013-componentes-angular-material/README|ADR-0013]]),
  con los valores del JSON entrando por `mat.theme-overrides()` uno por uno — el
  equivalente en web de lo que ADR-0009 §2 decidió en Flutter al prohibir `fromSeed`.
- **Los dos temas desde el primer componente** (regla 23): arranca en la preferencia
  del sistema, se puede forzar claro u oscuro, y la elección persiste.
- **Transloco** con catálogos `en` y `es` ([[../../../adr/0005-libreria-i18n-angular/README|ADR-0005]]).
  Sin sesión todavía, el idioma inicial sale del navegador.
- Una pantalla de verificación de tokens, equivalente a la que el móvil ya tiene en
  `dev`: sin algo que muestre cada color, espaciado y tipografía al lado del otro, no
  hay forma de comprobar la paridad entre superficies mirando.

### No entra

- **Login, sesión y shell.** Van en
  [[../0008-sesion-y-shell/README|SPEC-0008]], que depende de este.
- **El contenido de cualquier pantalla del panel.** Cada una lleva su spec.
- **`apps/site`** (Astro). Consumirá los mismos tokens generados, pero es otra
  superficie y otro spec.
- **Cambiar el idioma desde la interfaz y persistirlo.** Necesita saber quién está
  en sesión; va en SPEC-0008.
- **Rediseñar la paleta.** Los valores de `design-tokens.json` se toman como están.
  Si alguno no tiene equivalente en el vocabulario M3, se resuelve como dice
  ADR-0013 §3 — variable `--sl-*` propia—, no cambiándolo.

## Modelo de dominio afectado

**Ninguno.** Este spec no toca agregados, entidades, columnas ni contrato. Es
enteramente de superficie.

## Comportamiento sin señal

No aplica: `platform: web`, y además nada de este spec hace una llamada de red. Los
tokens se generan en build y los catálogos de traducción viajan con el bundle.

## Flujo de usuario

No hay flujo de usuario: nadie usa este spec directamente. Lo que produce es lo que
la próxima pantalla consume.

El flujo que sí importa es el del **valor de diseño**, que es lo que el `goal`
afirma:

```
design-tokens.json          ← se edita acá, y solo acá
        │
        └─ style-dictionary
              ├──▶ apps/web/…/tokens.css      ──▶ mat.theme-overrides()  ──▶ --mat-sys-*
              │                                                              --sl-*
              └──▶ apps/mobile/…/tokens.dart  ──▶ ColorScheme explícito
```

Cambiar un hex en el JSON y regenerar tiene que cambiarlo en las dos superficies.
Ningún archivo generado se edita a mano.

## Contrato de API

Ninguno. Este spec no agrega, modifica ni consume endpoints, y **no regenera
`openapi.json`**.

## UI

La pantalla de verificación de tokens, en los dos temas, con las secciones que la
del móvil ya tiene: colores, estado, acción primaria, tipografía y espaciado.

No es una pantalla de producto y no cuelga de la navegación — el shell todavía no
existe. Es el instrumento con el que se comprueba el `goal` mirando.

## Criterios de aceptación

- [ ] `apps/web` está en `pnpm-workspace.yaml`, y `pnpm typecheck`, `pnpm lint` y
      `pnpm build` desde la raíz la incluyen y pasan.
- [ ] Style Dictionary genera las variables CSS y `tokens.dart` desde
      `design-tokens.json`. **Cambiar un hex en el JSON y regenerar lo cambia en las
      dos superficies**; ningún archivo generado se edita a mano.
- [ ] **El `tokens.dart` generado es equivalente al que hoy está escrito a mano.**
      Se compara antes de reemplazarlo: si difiere, se resuelve la diferencia en vez
      de aceptarla — el móvil está en uso.
- [ ] Los archivos generados están marcados como generados y no se editan; el
      `pnpm test` del móvil sigue verde después del reemplazo.
- [ ] DEBT-0001 pasa a Resuelta en `docs/BOARD-tech-debt.md` y en su ficha.
- [ ] Los colores de Material salen de `mat.theme-overrides()` con los valores del
      JSON. **Ningún color del panel viene de la paleta que Material deriva solo.**
- [ ] **Ningún hex literal en un `.scss` de componente** (regla 22), y ningún
      componente con `template:` o `styles:` inline (regla 21).
- [ ] La pantalla de verificación se ve correcta en claro y en oscuro, arranca en la
      preferencia del sistema, y el override manual sobrevive a la recarga.
- [ ] Los mismos tokens puestos lado a lado en el teléfono y en el navegador dan el
      mismo color. Es la verificación del `goal`, y se hace mirando.
- [ ] **Cero cadenas quemadas** (regla 24) en lo que se construya, con `en` y `es`
      cargando por Transloco.
- [ ] **Forzar el locale cambia el texto que se ve.** Con `es` y con `en` la
      pantalla de verificación renderiza distinto, y ninguna clave queda sin traducir
      en uno de los dos catálogos. Es el equivalente para idioma del criterio que el
      tema ya tiene.

## Riesgos / consideraciones

- **Toca `apps/mobile`, que está en uso y con trabajo en vuelo.** Por eso el
  criterio no es "el generador funciona" sino "lo generado es equivalente a lo que
  ya había". Reemplazar `tokens.dart` por algo que difiera en un tono cambia la app
  sin que nadie lo haya pedido.
- **Que un token del JSON no tenga equivalente en el vocabulario M3** — las banderas
  de asistencia, por ejemplo. Resuelto por ADR-0013 §3: va como `--sl-*` propia,
  generada del mismo archivo.
- **Que Style Dictionary no cubra el formato Dart de fábrica** y haya que escribirle
  un formatter propio. Es trabajo acotado, pero conviene descubrirlo temprano.
- **El look de Material se nota.** Aceptado en ADR-0013 a cambio de la paridad.

## ADRs relacionados

- [[../../../adr/0002-superficies-flutter-angular/README|ADR-0002]] — el riesgo de deriva que este spec cierra
- [[../../../adr/0005-libreria-i18n-angular/README|ADR-0005]] — Transloco
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — los tokens canónicos y las tres capas
- [[../../../adr/0013-componentes-angular-material/README|ADR-0013]] — Angular Material y CDK, con los tokens por `theme-overrides`

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-30 | borrador | Creado. Sale de partir el spec original de cimientos en dos, tras la revisión de `spec-reviewer`: su `goal` cubría la sesión y el shell pero no el sistema de diseño, que es media spec en volumen |
