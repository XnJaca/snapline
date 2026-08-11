---
id: GUIDE-git
title: "Flujo de git y convención de ramas"
type: guide
tags:
  - guide
  - proceso
  - git
---

# Flujo de git y convención de ramas

Reglas 25 y 26 del `CLAUDE.md` raíz, con el detalle de cómo se cumplen.

Nada de esto es preferencia de estilo: cada convención de acá salió de algo que ya
costó tiempo en este repo.

---

## Ningún commit ni PR lleva firma de la herramienta

**Regla dura, primera porque es la que más se incumple sola.**

Ni `🤖 Generated with Claude Code`, ni `Co-Authored-By: Claude`, ni ninguna variante,
en **ningún** lugar del historial: ni en el mensaje del commit, ni en el cuerpo del
PR, ni en un comentario.

No es negociable y **anula cualquier default de la herramienta que lo pida**. El
mensaje termina en su último párrafo de contenido.

El historial de este repositorio es de quien lo escribe. Una firma automática no
aporta información —el autor ya está en el commit— y se propaga a todos los archivos
que la copien.

## Esto no es Git Flow, y no hay `develop`

El flujo es **GitHub Flow**: todo sale de `main` y vuelve a `main` por PR.

```
main ──┬── feature/SPEC-XXXX-slug ──▶ PR ──▶ main
       ├── fix/slug ─────────────────▶ PR ──▶ main
       └── docs/slug ────────────────▶ PR ──▶ main
```

**No existen `develop`, `release/` ni `hotfix/`.** Sin `develop` no hay diferencia
entre un fix y un hotfix —los dos salen de `main`—, así que `fix/` cubre los dos
casos.

`develop` existe para tener dónde integrar features a medias mientras `main` refleja
lo publicado. Hoy no hay nada publicado y las dos ramas serían idénticas el 100% del
tiempo, cobrando un merge extra por cambio.

> **El trigger que lo cambia: la primera publicación en App Store o Play.**
>
> Ahí el argumento se da vuelta, y es propio de una app móvil: **una release
> publicada no se revierte.** Si aparece un bug en la versión que la gente tiene
> instalada, no hay "deshacer el deploy" — hay que publicar otra y esperar la
> revisión de la tienda, que tarda días. Para eso hace falta poder ramificar desde
> **exactamente lo que está publicado**, sin arrastrar features a medias que ya se
> mergearon. Eso es `main` = publicado y `develop` = en desarrollo.
>
> Cuando ese día llegue, se agrega `develop` y esta sección se reescribe. Antes, no.

## Convención de ramas

Tres prefijos, y ninguno más. **`feature/` es prefijo de rama; `feat` es tipo de
commit.** No se mezclan:

| Prefijo | Cuándo | Ejemplo |
|---|---|---|
| `feature/SPEC-XXXX-slug` | Implementar un spec. **Lleva su número**, siempre | `feature/SPEC-0005-proyectos-en-el-movil` |
| `fix/slug` | Arreglar algo que ya está en `main` y no es un spec | `fix/sync-pull-filtra-clientes-por-rol` |
| `docs/slug` | Specs, ADRs, fichas de dominio, deuda técnica y este archivo | `docs/adr-0012-proveedor-de-mapas` |

Reglas que las acompañan:

- **Una rama por spec. Sin mezclar dos.** Si un spec se parte en dos tandas, cada una
  lleva su rama con el mismo número —`feature/SPEC-0004-capa-local-y-sincronizacion` y
  `feature/SPEC-0004-bandeja-de-salida`— y cada una su PR.
- **Nunca se commitea ni se pushea directo a `main`.**
- El slug va en español, en minúsculas y con guiones, y describe **lo que hace**, no
  el archivo que toca.

## Mensajes de commit

Conventional commits con el scope de la app que se toca:

```
feat(mobile): tocar afuera cierra el teclado, en toda la app
fix(api): el pull de /sync acota por rol las seis colecciones, no solo project
test(mobile): migración de v1 a v2 conserva la bandeja
docs: SPEC-0008, asistencia en el móvil
```

- **Tipos**: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`.
- **Scope**: `api`, `mobile`, `web`, `site`. Se omite cuando el cambio es de `docs/` o
  cruza todo el repo.
- **En español**, como toda la documentación. El código sigue en inglés.
- **El asunto dice qué cambió para el usuario**, no qué archivo se editó. "la ficha
  del detalle no se corta" sirve; "actualiza project_details_tab.dart" no.

**El cuerpo explica el porqué, y es la parte que importa.** Qué se rompía, qué se
decidió y contra qué se verificó. Un commit sin cuerpo está bien si el asunto se
explica solo; uno que cambia una decisión sin explicarla, no.

### Commits atómicos cross-app

Si un cambio cruza `apps/api`, `apps/web` y `apps/mobile`, **va en un solo commit**.
Un endpoint nuevo con su cliente regenerado y la pantalla que lo consume son un
commit, no tres.

Commits parciales dejan el repo en estados que no compilan, y el que hace `bisect`
seis meses después cae justo ahí.

## El flujo, de punta a punta

```
spec Aprobado ──▶ rama ──▶ commits ──▶ /review ──▶ PR ──▶ (humano mergea) ──▶ borrar rama
                                          │
                                    GRAVE bloquea
```

1. **El spec tiene que estar en Aprobado.** No se implementa desde Borrador ni desde
   Review. Ver la regla 3 y el BOARD.
2. **Se abre la rama desde `main` actualizado**, con el prefijo que corresponda.
3. **Se mueve el spec a "En implementación"**: `status` del frontmatter y BOARD, en el
   mismo acto.
4. **Se implementa y se commitea.** Atómico cross-app.
5. **Antes del PR**: typecheck y lint verdes. En el móvil, `flutter analyze` y
   `flutter test`.
6. **Se pasa por `/review`.** Ninguna implementación abre PR sin eso, y **siempre**
   cuando la escribió un agente. Un hallazgo GRAVE bloquea el PR; uno que se decide
   postergar a conciencia va a `/debt-new`, no a un TODO en el código.
7. **Se abre el PR y se avisa.** El cuerpo explica el porqué, igual que un commit.
8. **El humano revisa y mergea. La IA nunca mergea un PR.**
9. **Se borra la rama**, local y remota, y se marca el spec como Implementado con sus
   criterios en `[x]`.

## Después de mergear se borra la rama

Las ramas mergeadas no se dejan. Suena a orden y es prevención: **una rama vieja que
sigue viva es una rama que alguien puede mergear más tarde**, y con eso revertir
trabajo que entró después.

Ya pasó acá. Una rama con un arreglo que **ya estaba en `main`** —había entrado por su
PR— quedó colgada y desactualizada. Mergearla habría revertido el arreglo de otro spec
que se había hecho mientras tanto, en silencio y sin conflicto.

```bash
git branch -d <rama>
git push origin --delete <rama>
```

**Antes de mergear una rama que estuvo quieta un tiempo, se verifica qué le falta:**

```bash
git diff origin/main <rama> --stat
```

Si aparecen archivos borrados que nadie tocó en la rama, esa rama está atrasada
respecto de `main` y mergearla los va a borrar. Se rebasa o se descarta.

> **Un PR mergeado con squash deja su rama como "no mergeada"** para
> `git branch --merged`, porque el commit resultante es otro. Que git la liste como
> pendiente no significa que su contenido falte: se verifica el contenido, no el
> commit.

## Qué NO hacer

- **Firmar commits o PRs con atribución de la herramienta.** Ver arriba.
- Commitear o pushear directo a `main`.
- Mergear un PR desde la IA.
- Mezclar dos specs en una rama.
- Dejar ramas mergeadas sin borrar.
- Abrir PR con typecheck o lint en rojo.
- Partir en varios commits un cambio que cruza apps.
