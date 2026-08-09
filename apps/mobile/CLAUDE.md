# CLAUDE.md — apps/mobile

App de campo en Flutter. Las reglas duras están en el `CLAUDE.md` raíz; acá va lo
específico de esta carpeta. La arquitectura se decidió en ADR-0008 y el sistema de
diseño en ADR-0009.

**Esta app está fuera del workspace de pnpm**, a propósito: pub y pnpm no se
mezclan. No aparece en `pnpm-workspace.yaml` y no la toca `turbo`.

## Levantar en desarrollo

```bash
flutter pub get
dart run swagger_parser                              # cliente desde openapi.json
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Los tres comandos del medio son obligatorios después de clonar: **el código
generado no se versiona.** Son ~240 archivos y versionarlos haría ilegible el diff
de cualquier PR.

## Código generado — qué lo produce

| Qué | Comando | Sale en |
|---|---|---|
| Cliente y DTOs del API | `dart run swagger_parser` | `lib/api/` |
| `.g.dart` de json_serializable, Retrofit y Drift | `dart run build_runner build` | junto a su fuente |
| `AppLocalizations` | `flutter pub get` o `flutter gen-l10n` | `lib/l10n/` |

`lib/api/` **no se edita a mano.** Sale de `openapi.json` en la raíz del monorepo,
que emite el API desde sus DTOs. Si falta un campo, el arreglo va en `apps/api`, no
acá. Ver ADR-0007.

El orden importa: `swagger_parser` primero, porque `build_runner` genera los
`.g.dart` de lo que aquel escribió.

## Estructura

```
lib/
├── core/            tema, i18n, router, db, red, errores
├── api/             generado — no se edita
├── data/            tablas Drift, repositorios, sincronizador y bandeja de salida
└── features/        una carpeta por frente del producto
```

Por feature, no por capa: agregar una pantalla toca un solo directorio.

## Offline es el camino normal, no un caso especial

**La UI nunca lee de la red.** Lee de Drift y observa sus streams; el sincronizador
escribe en Drift y la pantalla se actualiza sola. Sin señal no hay ninguna ruta
distinta que recorrer.

- Toda fila que sincroniza lleva `sync_status`: `PENDING | SYNCING | SYNCED | CONFLICT`.
- `CONFLICT` solo lo produce `time_entry` y **lo resuelve un humano** (regla 12).
  Todo lo demás va con última escritura gana.
- Las mutaciones pendientes viven en una **tabla** de bandeja de salida, no en
  memoria: sobreviven a que el sistema mate la app.
- Cada una guarda su clave de idempotencia y se reintenta con esa misma (regla 19).
- Los IDs son UUIDv7 **generados en el dispositivo** (regla 18). El registro nace
  con su ID definitivo.

## Tema — cero valores literales

Los widgets consumen el tema. Un `Color(0x...)`, un `EdgeInsets.all(16)` o un
`fontSize: 16` fuera de `lib/core/theme/` es un error de revisión.

```dart
// ❌
Container(padding: const EdgeInsets.all(16), color: const Color(0xFF1D4ED8))

// ✅
Container(padding: EdgeInsets.all(context.spacing.lg), color: context.colors.primary)
```

Los accesos son `context.spacing`, `context.colors`, `context.texts` y
`context.statusColors`, definidos en `core/theme/theme_extensions.dart`.

- `context.colors` es el `ColorScheme` de Material: `error` es danger, `outline` es
  border y `onSurfaceVariant` es el texto atenuado.
- `context.statusColors` tiene solo lo que Material no cubre: `warning` y `success`
  con sus variantes `container`, que son las banderas de asistencia.

### La regla del naranja

El acento está a 17 grados del rojo de error y a 18 del ámbar de las banderas. Medido.
El tono no alcanza para distinguirlos, así que lo hace la forma:

- **El naranja saturado es exclusivo de la acción primaria.** Un botón sólido por
  pantalla. Si dos cosas son naranjas, ninguna es la acción.
- **Los estados van siempre en `container` / `onContainer`**: fondo tenue, texto
  oscuro, icono. Nunca relleno sólido.
- **El icono es obligatorio en todo estado.** Nunca color solo.

```dart
// ❌ compite con la acción primaria y depende solo del color
Container(color: context.statusColors.warning, child: Text(l10n.flagOutsideGeofence))

// ✅
Container(
  color: context.statusColors.warningContainer,
  child: Row(children: [
    Icon(Icons.warning_amber_rounded, color: context.statusColors.onWarningContainer),
    Text(l10n.flagOutsideGeofence),
  ]),
)
```

### Los estados se muestran con `StatusChip`

No se arma a mano un contenedor de color: `core/widgets/status_chip.dart` ya trae
el par `container`/`onContainer` y el icono obligatorio por tono.

```dart
StatusChip(tone: StatusTone.warning, label: l10n.flagOutsideGeofence)
StatusChip(tone: StatusTone.danger, label: mensaje, expand: true)  // error de formulario
```

`expand: true` ocupa el ancho, para errores de formulario. Sin él queda compacto,
para banderas.

### Sesión

`core/session/` es la única puerta a la sesión. Nadie lee tokens de otro lado.

- `sessionControllerProvider` — `AsyncValue<Session?>`; `null` es que no hay sesión.
- La sesión vive en Keychain/Keystore, nunca en la base local ni en preferencias.
- **Un refresh fallido no borra la sesión.** Solo `signOut()` la elimina. Un token
  vencido sin red no puede dejar a un trabajador sin poder capturar.
- El `AuthInterceptor` renueva en `401` y reintenta la petición **una vez**. Varias
  peticiones en paralelo comparten un solo refresh.
- Login y refresh usan `bareDioProvider`, sin interceptor: si no, un login fallido
  dispararía un refresh sobre sí mismo.

### Tipografía y tamaño de toque

Dos familias, y no se cruzan:

- **Inter** — todo el texto de interfaz. Es la del tema, así que sale sola.
- **Bricolage Grotesque** — **solo el wordmark**, dentro de `core/brand/`. Ningún
  texto de interfaz la usa.

Las dos van embebidas como asset. **No se usa `google_fonts`**: descarga en runtime
y esta app trabaja sin señal.

La marca tiene dos lockups: `SnaplineLogo` horizontal y atenuado para barras, y
`SnaplineLogoStacked` vertical y en color pleno para pantallas donde la marca es
protagonista. El horizontal no crece — a tamaño grande desborda en pantallas
angostas; para eso está el vertical.

Las cifras que corren o se leen en columna —cronómetro, montos— llevan
`FontFeature.tabularFigures()`, que ya trae `displaySmall`. Sin eso el texto se
mueve en cada segundo.

El mínimo táctil de Material es 48dp; acá **la acción primaria es de 64dp y ancho
completo**, porque un dedo con guante de trabajo no acierta un botón de 48.

Ningún control se dimensiona al texto en inglés: "Clock in" son 8 caracteres y
"Marcar entrada" son 14. Si el label no entra en español, el diseño está mal.

Los valores salen de `design-tokens.json` en la raíz, traducidos a
`core/theme/tokens.dart` **a mano** hasta que exista el generador (DEBT-0001).
Si cambia uno, se cambian los dos archivos en el mismo commit.

**`ColorScheme.fromSeed` no se usa nunca.** Derivaría colores distintos a los que
usa Angular desde el mismo JSON. Ver ADR-0009.

Toda pantalla se prueba en claro y en oscuro. La pantalla de tokens (`/`) sirve para
verificarlo de un vistazo.

## i18n — cero cadenas quemadas

Ningún texto visible al usuario se escribe literal en un `.dart`.

```dart
// ❌
Text('Clock in')

// ✅
Text(AppLocalizations.of(context).clockIn)
```

Las claves son jerárquicas por frente y pantalla, en camelCase porque `gen-l10n`
las convierte en getters: `timeEntryClockInButton`, no `time_entry.clock_in.button`
ni `clockIn`.

Los dos idiomas, `en` y `es`, se agregan en el mismo commit. Lo que falte queda
listado en `l10n-faltantes.txt` al generar.

El locale es **por usuario**, no por empresa: William administra en inglés y sus
trabajadores probablemente usen la app en español, en la misma cuenta.

## Antes de abrir PR

```bash
flutter analyze
flutter test
```

### Tests de integración

`integration_test/` corre contra el **API de verdad**, en un simulador. Es lo único
que verifica de punta a punta que se entra con teléfono o con email y que el idioma
sale del usuario.

```bash
# desde la raíz del monorepo
pnpm api:db:up && pnpm api:migrate && pnpm api:seed && pnpm api:dev

# en otra terminal
flutter test integration_test/login_test.dart -d <id-del-simulador>
```

Usuarios del seed: `william@pcdmv.com` (locale `en`, OWNER) y `+15551234567`
(locale `es`, WORKER). Contraseña `Snapline123!` para los dos.

**No afirmes textos de UI que dependan del idioma** cuando no hay sesión: sin
`user.locale` la app cae al idioma del dispositivo, y el test pasa o falla según
cómo esté configurado el simulador.

## Qué NO hacer

- Editar nada de `lib/api/`: se regenera y se pierde.
- Leer de la red desde un widget. Siempre pasa por Drift.
- Resolver un conflicto de `time_entry` automáticamente.
- Borrado duro en tablas que sincronizan (regla 20).
- Aceptar del servidor —o mandarle— valores que él deriva: `withinGeofence`,
  `distanceM`.
- Bloquear el marcaje por falta de GPS, foto o red (regla 9). Se registra con lo
  que haya y se marca con bandera.

## Pendiente conocido

`riverpod_generator` y `riverpod_lint` **no están instalados**: las versiones
compatibles con Riverpod 3 exigen Dart ≥3.12 y el Flutter fijado trae 3.11.5. Los
providers se escriben con la API manual (`Notifier` + `NotifierProvider`), que es
equivalente. Al subir Flutter se pueden agregar sin tocar lo escrito.
