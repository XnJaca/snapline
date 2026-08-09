---
id: ADR-0008
title: "Arquitectura de la app Flutter: Riverpod, Drift y cliente generado"
aliases:
  - "ADR-0008: Arquitectura de la app Flutter: Riverpod, Drift y cliente generado"
type: adr
status: propuesto
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/propuesto
  - mobile
---

# ADR-0008: Arquitectura de la app Flutter: Riverpod, Drift y cliente generado

> **Meta**
> - Deciders: @jaca
>
> _Estado y fecha viven en el frontmatter arriba — no duplicar aquí._

## Contexto

`apps/mobile` no existe todavía y es la superficie de la que depende el ciclo
completo del producto: sin captura en sitio no hay contenido que publicar ni horas
que reportar.

Cuatro reglas duras del dominio condicionan la arquitectura antes que cualquier
preferencia de estilo:

- **Regla 9** — marcar asistencia nunca puede fallar. Sin red, sin GPS y sin permiso
  de cámara, la marca se registra igual.
- **Regla 18** — los IDs son UUIDv7 generados en el dispositivo. El registro nace
  con su ID definitivo y no se reconcilia nada al sincronizar.
- **Regla 19** — toda mutación lleva clave de idempotencia, porque la red se cae a
  mitad de un POST y el reintento no puede duplicar.
- **Regla 12** — un conflicto de sincronización en `time_entry` no se resuelve solo:
  se marca y lo revisa un humano.

Eso no es "una app con caché". Es una app cuya fuente de verdad local es una base
de datos con estado de sincronización por fila, y que empuja los cambios pendientes
en orden cuando vuelve la señal.

El contrato ya está resuelto en [[../0007-openapi-como-contrato/README|ADR-0007]]:
`openapi.json` es la fuente y Flutter genera sus modelos de ahí. Lo que ese ADR no
decidió es **con qué herramienta**, y la que nombra —`openapi-generator`— necesita
una JVM que no está instalada en la máquina de desarrollo.

## Decisión

Cinco piezas, cada una con una responsabilidad que no se solapa con las otras:

| Pieza | Elección | Responsabilidad |
|---|---|---|
| Estado | **Riverpod 3** + `riverpod_generator` | Estado de UI y orquestación |
| Base local | **Drift** (SQLite) | Fuente de verdad en el dispositivo y bandeja de salida |
| Navegación | **go_router** | Rutas declarativas y deep links |
| HTTP | **Dio** + Retrofit | Transporte, interceptores de auth y reintento |
| Modelos | **`swagger_parser`** desde `openapi.json` | Cliente y DTOs generados, sin JVM |
| Sesión | **`flutter_secure_storage`** | Tokens en Keychain y Keystore |

### La base local es la fuente de verdad, no un caché

La UI **nunca** lee de la red. Lee de Drift y observa sus streams; la sincronización
escribe en Drift y la pantalla se actualiza sola. Esa inversión es lo que hace que
la regla 9 se cumpla sin código especial por pantalla: sin señal no hay ninguna
ruta distinta que recorrer, porque la ruta con señal ya pasaba por la base local.

Cada tabla que sincroniza lleva su estado propio:

```
sync_status   PENDING | SYNCING | SYNCED | CONFLICT
```

`CONFLICT` existe por la regla 12 y solo lo produce `time_entry`. Todo lo demás
resuelve con última escritura gana y nunca llega a ese estado.

### La bandeja de salida es una tabla, no una lista en memoria

Una mutación pendiente sobrevive a que el sistema operativo mate la app — que es
exactamente lo que pasa cuando el teléfono queda en el bolsillo cuatro horas. Cada
fila guarda la clave de idempotencia con la que se reintenta, así que el mismo
POST puede salir tres veces sin duplicar nada del lado del servidor.

### Riverpod 3 no reemplaza a Drift

Riverpod 3 trae persistencia offline propia (`@JsonPersist()`, `riverpod_sqflite`).
**No se usa para los datos del dominio**, por tres razones concretas:

1. Persiste el estado de un provider como JSON. No permite consultar "todas las
   fotos con `sync_status = PENDING` de cualquier proyecto", que es literalmente
   lo que hace el sincronizador.
2. Su modelo es caché con vencimiento; el nuestro es fuente de verdad. Una foto
   tomada sin señal no puede expirar antes de subirse.
3. Sigue marcada como experimental en la 3.x.

Queda disponible para estado accesorio que sí es caché —preferencias de UI, último
proyecto abierto— y ahí no hay problema.

### El material de sesión no vive en la base local

*Agregado el 2026-08-08, al revisar el [[../../specs/mobile/0001-login-movil/README|SPEC-0001]]:
la decisión estaba tomada dentro de un spec de feature y la regla 4 la pone acá.*

Los tokens van en **Keychain (iOS) y Keystore (Android)** vía `flutter_secure_storage`,
nunca en `SharedPreferences` ni en una tabla de Drift.

El refresh token dura 30 días y **es la credencial más valiosa del dispositivo**:
quien lo obtiene puede emitir tokens de acceso durante un mes sin conocer la
contraseña. Guardarlo con los datos del dominio lo ata al ciclo de vida de esos
datos —migraciones, borrados, respaldos— cuando su ciclo es el de la sesión.

Separarlo también hace que cerrar sesión sea una operación clara: se borra el
material de sesión, y los datos locales se descartan aparte según su propia regla.

**Alternativa considerada — cifrar la base Drift y guardar los tokens adentro.**
Drift lo soporta con SQLCipher y evitaría la dependencia. Se descarta porque la
llave de ese cifrado tendría que guardarse en algún lado, y ese lado termina siendo
el Keychain: se agrega una capa sin quitar la que se quería evitar. Cifrar la base
sigue siendo una opción por su propio mérito —proteger las fotos y los registros en
un teléfono robado—, pero es una decisión distinta y no reemplaza a esta.

### Estructura

Por feature, no por capa técnica. Las carpetas de la app siguen los frentes del
producto y no una taxonomía de arquitectura, para que agregar una pantalla toque
un solo directorio.

```
lib/
├── core/            tema, i18n, router, db, red, errores
├── api/             generado por swagger_parser — no se edita a mano
├── data/            tablas Drift, repositorios, sincronizador y bandeja de salida
└── features/        auth, projects, time_entries, media
```

## Alternativas consideradas

### Alternativa A — Riverpod 3 con su persistencia nativa, sin Drift

Una dependencia menos y menos código de infraestructura.

**Por qué no:** las tres razones de arriba. El sincronizador necesita consultar por
estado a través de toda la base, y eso es una consulta relacional. Construirlo
sobre un caché JSON significa cargar todo en memoria para filtrarlo.

### Alternativa B — `openapi-generator` oficial, como nombra el ADR-0007

Es el generador estándar y el que ya estaba escrito en la decisión.

**Por qué no:** necesita una JVM. Hoy no hay ninguna instalada y agregar Java a los
requisitos de build de una app Flutter es costo permanente —en CI también— a cambio
de nada que `swagger_parser` no dé. Este ADR **corrige ese detalle del ADR-0007**;
la decisión de fondo, que `openapi.json` es la fuente única, no cambia.

### Alternativa C — BLoC en vez de Riverpod

Es el otro estándar de facto y tiene más material de referencia.

**Por qué no:** Riverpod ya se usa en ACDEMIC, así que no hay curva. Y para una app
donde casi todo es "observar una consulta local y reflejarla", los streams de
Riverpod sobre los de Drift son menos ceremonia que un bloc por pantalla.

### Alternativa D — Isar como base local

API más simple que Drift y buen rendimiento.

**Por qué no:** su mantenimiento fue irregular y el esquema del servidor es
relacional. Duplicarlo en una base de documentos obliga a traducir en los dos
sentidos; SQLite deja las tablas locales parecidas a las del API.

## Consecuencias

### Positivas

- Offline deja de ser una feature y pasa a ser la forma en que la app funciona
  siempre. No hay dos caminos que mantener alineados.
- Un cambio de campo en un DTO del API llega a Dart por el mismo comando que a
  TypeScript, y el compilador señala qué se rompió.
- `unknown_enum_value` deja que el servidor agregue valores de enum sin tumbar
  las versiones ya instaladas — importa porque el teléfono de un trabajador se
  actualiza cuando quiere, no cuando sale el release.
- Cero JVM en el pipeline de build.

### Negativas / Costos

- Dos generadores de código en el proyecto (`build_runner` para Drift y Riverpod,
  `swagger_parser` para el cliente). Compilar en frío es más lento.
- El esquema local hay que mantenerlo alineado con el del servidor a mano: las
  tablas de Drift no se generan desde `openapi.json`.
- Migraciones de la base local, con su propio versionado, aparte de las del API.

### Riesgos

- **La bandeja de salida es la pieza con más superficie de bug del móvil**, y sus
  fallos aparecen en condiciones difíciles de reproducir. Mitigación: es lo primero
  que se cubre con tests, y el orden de envío es determinista, no concurrente.
- ~~**Que `swagger_parser` no digiera bien nuestro spec.**~~ **Verificado el
  2026-08-08**: genera 10 clientes, 56 requests y 48 data classes en 0.036s, y
  `build_runner` cierra los `.g.dart` sin un solo error de análisis. El riesgo se
  cierra por el lado de la herramienta.
  Lo que sí se confirmó es el problema del contrato: los 12 schemas de respuesta
  sin propiedades producen clases vacías —`class MediaAsset { const MediaAsset(); }`—
  que parsean la respuesta y descartan todo. **Es trabajo de `apps/api`**, no de acá.
- **Riverpod 3.x sigue moviéndose** (`family.overrideWith` quedó deprecado en 3.2).
  Mitigación: `pubspec.lock` se versiona, así que la versión exacta es reproducible.

- **`riverpod_generator` y `riverpod_lint` exigen Dart ≥3.12** en las versiones
  compatibles con Riverpod 3, y el Flutter fijado (3.41.9) trae Dart 3.11.5. Las
  versiones anteriores dependen de un `analyzer` que choca con `drift_dev`, así que
  no hay combinación que funcione sin subir el SDK.
  Mitigación aplicada: los providers se escriben con la API manual —`Notifier` +
  `NotifierProvider`—, que es equivalente y no bloquea nada. La anotación `@riverpod`
  es azúcar, y agregarla al subir a Flutter 3.44 no obliga a reescribir lo hecho.

## Impacto en el modelo

Ninguno. El esquema del servidor manda; la base local lo espeja parcialmente.

- [[../../domain/registro-de-tiempo|registro-de-tiempo]] — la única entidad que
  puede quedar en `CONFLICT`
- [[../../domain/contenido|contenido]] — las fotos pasan por la bandeja de salida

## Referencias

- [[../0007-openapi-como-contrato/README|ADR-0007]] — este ADR corrige la
  herramienta de generación para Dart, no la decisión de fondo.
- [[../0003-asistencia-geocerca-foto/README|ADR-0003]] — de dónde sale que marcar
  no puede fallar.
- Reglas 9, 12, 18, 19 y 20 del `CLAUDE.md` raíz.
- Verificado con Context7 el 2026-08-08: Riverpod 3.x, Drift y `swagger_parser`.
