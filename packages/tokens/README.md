# @snapline/tokens

Genera los tokens de diseño de cada superficie desde `design-tokens.json` en la
raíz, que es la fuente única (ADR-0009 §1).

```bash
pnpm tokens:generate     # desde la raíz del monorepo
```

| Salida | Para |
|---|---|
| `apps/web/src/styles/_tokens.scss` | Los mapas que alimentan `mat.theme-overrides()`, y las variables `--sl-*` |
| `apps/mobile/lib/core/theme/tokens.dart` | Las tres clases que consume `AppTheme` |

**Los dos archivos son generados y no se editan.** Un cambio de color se hace en el
JSON y se regenera; editar la salida se pierde en el siguiente build.

## Por qué existe

Cierra [DEBT-0001](../../docs/tech-debt/0001-tokens-a-dart-a-mano.md): hasta que
existió esto, `tokens.dart` se escribía a mano copiando del JSON y **nada validaba
que coincidieran**. Se podía cambiar un color en el JSON y que la app siguiera
compilando con el valor viejo, sin ningún aviso.

Con dos superficies consumiendo la misma fuente, esa deriva dejaba de ser
hipotética — es el riesgo que ADR-0002 declaró y ADR-0009 quiso cerrar.

## Cómo se lee el JSON

No está en el formato del W3C ni en el que Style Dictionary espera: los valores van
desnudos (`"primary": "#C2410C"`, no `{"value": "#C2410C"}`) y los comentarios son
`$comment`. `toTokens()` traduce ese árbol antes de pasárselo.

**El `$comment` de un grupo se emite como docblock encabezando su bloque.** Por eso
las explicaciones —por qué el target de campo son 64dp, por qué las tipografías van
embebidas— viven en el JSON y no en el archivo generado: ahí se perderían al
regenerar.

## Los dos alias

Casi todos los nombres salen mecánicamente del árbol: `touch-target.field` produce
`touchTargetField`. Dos no, y están en `DART_ALIASES`:

| En el JSON | En Dart | Por qué |
|---|---|---|
| `font.family.ui` | `fontFamily` | La familia de interfaz es *la* familia; `fontFamilyUi` sugiere que hay que elegir |
| `font.weight.*` | `weight*` | Los pesos se usan sueltos, sin el prefijo de su grupo |

Los widgets ya los consumen con esos nombres. Si la tabla crece, conviene replantear
la estructura del JSON en vez de sumar excepciones.

## Al agregar un token

1. Va al JSON, en su grupo. Si necesita explicación, `$comment` en el grupo.
2. `pnpm tokens:generate`.
3. Si el nombre generado en Dart no es el que se quiere, **cambiar la estructura del
   JSON** antes que agregar un alias.
