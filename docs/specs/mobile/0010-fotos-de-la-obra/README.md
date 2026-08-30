---
id: SPEC-0010
title: "Fotos de la obra"
aliases:
  - "SPEC-0010: Fotos de la obra"
type: spec
platform: mobile
status: en-implementacion
goal: "Una foto tomada en la obra sin señal aparece en la galería de esa obra con la etiqueta que se le haya puesto, sube sola cuando vuelve la red, y solo OWNER o ADMIN pueden subirla de nivel, de a un escalón."
apps:
  - mobile
  - api
depends_on:
  - "0004-capa-local-y-sincronizacion"
  - "0008-asistencia-en-el-movil"
  - "0009-la-obra-como-lugar"
domain:
  - contenido
  - proyecto
frente: campo
created: 2026-08-12
updated: 2026-08-30
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0010: Fotos de la obra

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0004-capa-local-y-sincronizacion/README|SPEC-0004]],
>   [[../0008-asistencia-en-el-movil/README|SPEC-0008]],
>   [[../0009-la-obra-como-lugar/README|SPEC-0009]]
> - Frente: `campo`

---

## Problema

**La segunda pata de la visión no tiene camino de punta a punta.** El producto
apuesta a dos cosas a la vez, y una es *"la foto termina publicada"* — el único
frente que le produce dinero a William en vez de ahorrarle tiempo.

Hoy falta el primer paso de ese ciclo:

| Pieza | Estado |
|---|---|
| El API publica | 10 endpoints en `publishing`: publicar, antes/después, feed público y de redes |
| El móvil sabe subir un binario | `MediaRepository` con bandeja de subida, reintento por checksum, probado contra Backblaze |
| El pull de `/sync` baja `media_asset` | Con scope por rol: un `WORKER` solo ve las de sus obras asignadas |
| **Tomar una foto de la obra** | **No existe.** Solo se capturan fotos de marcaje |
| **Verlas** | **No existe.** No hay tabla local de assets ni pantalla |

El trabajador toma fotos para fichar, no para mostrar la obra. Publicar no tiene
de dónde elegir, y el `before_after_pair` —que la ficha de [[contenido]] llama
*"la pieza de marketing del producto"*— no tiene con qué armarse.

## Alcance

### Entra

- **Tomar una foto desde la obra**, no desde el marcaje. Reusa
  `MediaRepository.registerPhoto`, que ya resuelve id local, checksum y bandeja.
- **Etiquetarla en el mismo gesto**, con las etiquetas que ya existen en el
  dominio: `BEFORE` · `DURING` · `AFTER` · `DETAIL` · `PROBLEM` · `RECEIPT`.
- **Verlas en un tab de la obra**, en grilla, más nuevas primero.
- **Subir de nivel** `INTERNAL → CLIENT → PUBLIC`, visible solo para quien tiene
  el permiso, **de a un escalón**.
- **En `apps/api`: `POST /media/:id/tags`**, que hoy no existe — `media_tag` tiene
  tabla y entity y ningún endpoint. Entra acá por la misma razón que
  [[../0006-clientes-en-el-movil/README|SPEC-0006]] trajo `site.update`: es este
  spec el que lo necesita.
- **En `apps/api`: las etiquetas dentro de `mediaAssets`** en el pull de `/sync`,
  y la operación `media.tag` en el push, o la etiqueta puesta sin señal no llega
  nunca. Por qué embebidas y no como colección propia, abajo.
- **En `apps/api`: la escalera se aplica en `setVisibility`** (decidido el
  2026-08-12). Hoy el servicio acepta cualquier salto: `INTERNAL → PUBLIC` directo
  pasa, contra lo que declara [[contenido]] desde la migración inicial. Este es el
  primer spec que pone ese botón frente a un usuario, así que es el que cierra el
  hueco en vez de dejarlo vivir en la pantalla.

### No entra

- **Publicar la obra.** El botón que llama a `POST /projects/:id/publish` va en su
  propio spec. Este deja el material listo y etiquetado; publicarlo es una acción
  deliberada de William y merece su propia pantalla.
- **Armar el par antes/después.** Su endpoint ya existe
  (`POST /projects/:id/before-after`) y la etiqueta que lo alimenta sale de acá,
  pero elegir cuál con cuál es del spec de publicación.
- **Editar la foto.** Recorte y filtros son otra categoría, y la ficha de
  [[contenido]] ya lo declara fuera.
- ~~**Borrar una foto.** Necesita borrado suave propagable (regla 20) y no hay
  caso de uso pedido todavía.~~ **Entró el 2026-08-13**, ver abajo.
- **Documentos.** `kind = DOCUMENT` y su `document_kind` no se capturan desde el
  teléfono en este alcance.

### Lo que se agregó al alcance mientras se implementaba

Probando en el teléfono aparecieron dos cosas que el spec no había previsto. Van
acá y no en otro spec porque son la misma pantalla y el mismo agregado.

**Borrar una foto — 2026-08-13.** Estaba declarado fuera con la razón de que no
había caso de uso; apareció uno concreto: fotos registradas cuyo binario no está
ni en el teléfono ni en el servidor —pasa si se cierra sesión antes de que suba—
no se pueden ver ni recuperar, y no había forma de sacarlas de en medio.

Entra con **permiso propio `media.delete`, acotado a `OWNER` y `ADMIN`**. La foto
es la evidencia de la obra y el "antes" no se puede volver a sacar cuando el
trabajo ya empezó: quien borra puede estar borrando la prueba de algo. Un
trabajador que saca una foto mala la descarta en el momento, sin registrarla.

Es **suave en la base y duro en el disco**: la fila queda con `deleted_at` para
que la baja se propague (regla 20) y el archivo local se borra de verdad, porque
es una copia y lo que se pidió fue liberar el espacio. El objeto del bucket no se
toca mientras la fila exista.

**Ver una foto que no está en el teléfono — 2026-08-13.** El spec decía que
"exige red" y lo daba por resuelto; no estaba implementado. Sin eso, toda foto
que baja del pull —la que tomó otro— se veía como un cuadro vacío. Se pide con
`GET /media/:id/url`, que ya existía.

## Modelo de dominio afectado

- [[contenido]] — `media_asset`, `media_tag` y la escalera de visibilidad
- [[proyecto]] — de dónde cuelgan las fotos

No agrega ningún agregado nuevo, y **ninguna migración**. Pero eso último no sale
gratis: hay que elegir cómo sincronizan las etiquetas.

### Por qué las etiquetas viajan dentro del asset

`media_tag` tiene `id`, `company_id`, `asset_id`, `tag` y `created_at`. **No tiene
`updated_at` ni `deleted_at`**, y el pull incremental depende estructuralmente de
las dos: `vivos()` filtra por `updated_at > desde`, `borrados()` busca
`deleted_at IS NOT NULL`. Como colección propia del pull, `media_tag` no se puede
construir.

Hay dos salidas y este spec toma la segunda:

| Salida | Costo |
|---|---|
| Migración que agrega las dos columnas | `media_tag` pasa a ser una tabla que sincroniza, con borrado suave propio (regla 20) para propagar una etiqueta quitada |
| **Las etiquetas viajan dentro de `mediaAssets`** | Cero migración. Cambiarlas toca `media_asset.updated_at`, y el asset viaja con su lista completa |

Se elige la segunda porque **las etiquetas no son un agregado**: nadie las consulta
sueltas, siempre se leen con su foto. Y como lo que se propaga al teléfono es el
asset con su lista entera, borrar filas de `media_tag` en el servidor deja de ser
un borrado que haya que propagar — el dispositivo recibe el conjunto nuevo y
reemplaza el suyo. El `UNIQUE (asset_id, tag)` que ya existe evita duplicados.

> **Lo que sí exige:** que el servicio toque `media_asset.updated_at` al cambiar
> las etiquetas. Si no lo hace, el pull incremental no se entera y la etiqueta
> puesta en un teléfono no aparece en el otro.

### Lo que sí cambia en la base local

| Tabla Drift | Cambio | Por qué |
|---|---|---|
| `MediaAssets` | **Nueva** | Hoy una foto registrada solo vive en `pending_uploads` hasta que sube, y después desaparece del teléfono. Sin tabla no hay galería offline |
| `MediaAssets.tags` | JSON | Mismo patrón que `TimeEntries.flags`: la lista se lee siempre con su fila y un valor nuevo del servidor no rompe la base local |
| `TimeEntries` | `clockInPhotoId` y `clockOutPhotoId` | Ya viajan en el contrato y hoy se descartan al mapear. Son el criterio para separar la foto de fichaje de la de obra |

Sube a `schemaVersion` 6, con `addColumn` y `createTable` — nada que recrear.

## Las reglas del dominio que aplican

- **La foto de marcaje no se mezcla con la galería** (decidido el 2026-08-12). Un
  asset referenciado por `time_entry.clock_in_photo_id` o `clock_out_photo_id` es
  evidencia de asistencia, no material de la obra. El filtro es un anti-join
  local; por eso las dos columnas nuevas.
- **`media.visibility` es de `OWNER` y `ADMIN`** — ya declarado en
  `permissions.ts`, no se decide acá. El `WORKER` y el `FOREMAN` capturan y ven;
  subir de nivel no aparece en su pantalla. El móvil **oculta la acción según
  `membership.permissions`**, nunca replicando la tabla de roles.
- **`PUBLIC` exige EXIF limpio** (regla 17), y lo aplica un trigger de la base.
  El servicio ya limpia solo al subir a `PUBLIC`, así que el móvil no hace nada
  especial — pero si el rechazo llega, se muestra con su código, no con prosa.
- **Dos marcas de tiempo** (regla 10): `captured_at` sale del EXIF de la foto, no
  de cuándo subió. Con offline la diferencia puede ser de días y el orden
  cronológico de la obra depende de eso.
- **Borrado suave** (regla 20) y **UUIDv7 del dispositivo** (regla 18): ya
  resueltos por `registerPhoto`, no se rehacen.

## Comportamiento sin señal

Es el caso de uso central, no el borde: la foto se toma en un techo sin cobertura.

| Acción | Sin señal |
|---|---|
| Tomar la foto | **Funciona igual.** Id UUIDv7 local, checksum, fila en `media_assets` y en `pending_uploads`, registro encolado en la bandeja |
| Etiquetarla | **Funciona igual.** La etiqueta se guarda local y viaja como operación `media.tag` con su clave de idempotencia (regla 19) |
| Verla en la galería | **La propia, sí**: se muestra desde el archivo del dispositivo |
| Ver las de otros | **No.** Se muestra el marco con su estado, no un error |
| Subir de nivel | **No.** La acción se deshabilita: es una decisión deliberada, no algo que deba encolarse y ejecutarse sola horas después |

**El binario local no se borra al subir.** Hoy `pending_uploads` es la única copia
y se limpia al confirmar; si se borrara, la foto que el trabajador acaba de tomar
desaparecería de su propia galería en cuanto hay señal. Se conserva y se limpia
por antigüedad, no por subida.

**Cuánto se conserva: un tope de 500 MB**, no una ventana de días (decidido el
2026-08-12). El límite que importa es el disco del teléfono, y una cuadrilla que
toma 200 fotos en dos días llena lo mismo que otra en dos meses — el calendario no
mide eso. A 1,5 MB por foto son unas 330 siempre disponibles sin señal.

Al pasar del tope se borran las **más viejas ya subidas**, hasta volver debajo.
Dos cosas no se borran nunca, por más que se pase:

- **Lo que todavía no subió.** Es la única copia que existe.
- **Lo que falló al subir.** Borrarlo sería descartar en silencio el trabajo del
  día, que es exactamente lo que la regla 9 evita en el marcaje.

Si el pendiente solo llegara a llenar el disco, el problema no es la retención
sino que algo no está subiendo, y eso se ve en la galería.

### Lo que puede fallar y no es la red

La red no es la única forma de que esto se caiga. Ninguno de estos casos bloquea
al trabajador, pero todos tienen que **decir qué pasó**:

| Falla | Qué hace la app |
|---|---|
| **Permiso de cámara denegado** | No hay escalera de evidencia alternativa acá: sacar la foto *es* la pantalla. Se explica qué falta y se ofrece abrir los ajustes del sistema. Nunca un diálogo vacío ni un botón que no responde |
| **No sube tras varios intentos** | La foto **nunca se descarta**. `MediaUploader` incrementa `attempts` sin tope; a partir del quinto la galería lo dice —"no se pudo subir"— con acción de reintentar. Hoy la UI solo distingue "en el teléfono" de "subida", y ese silencio es el problema |
| **El servidor la rechaza** por tipo o tamaño | El invariante se valida en el servidor, no solo acá ([[contenido]]). El rechazo se muestra con su `code` del envelope (ADR-0011), no con prosa traducida, y la foto queda marcada para que no se reintente para siempre |
| **El trigger rechaza `PUBLIC`** por EXIF sin limpiar | No debería pasar —el servicio limpia solo—, pero si pasa llega como `EXIF_NOT_STRIPPED` y se muestra como tal |

**Etiquetar deja de ser opcional — 2026-08-30.** El spec lo dejaba saltable para
no poner nada entre la cámara y guardar. Se revierte por decisión de producto: el
sistema existe para curar el desorden, y una foto sin etiqueta es exactamente el
desorden que viene a arreglar.

La hoja de una foto recién tomada **no se puede esquivar** —ni deslizando ni con
el botón atrás— y tiene dos salidas: guardar, que exige al menos una etiqueta, o
**descartar la foto**, que borra el archivo antes de que exista fila. Así no hay
camino que produzca una foto sin etiqueta, y tampoco hay que quedarse con una que
salió mal.

Corregir la etiqueta de una foto ya registrada tampoco puede dejarla en cero. El
grupo **Sin etiqueta** de la galería se conserva para las fotos anteriores a este
cambio: no se les puede inventar una, y verlas agrupadas ahí es lo que hace que
alguien las etiquete.

**Y es una sola etiqueta, no varias — 2026-08-30.** La hoja permitía marcar las
seis. La galería agrupa por etiqueta, así que una foto con dos aparecía dos veces:
duplicarla en la vista es el desorden que esto viene a ordenar, y "antes" y
"después" a la vez no significa nada.

El contrato no cambia —`tags` sigue siendo un arreglo, sin migración— y
`agruparPorEtiqueta` sigue tratando las de antes, que sí pueden traer varias. Lo
que cambia es que la app ya no las produce, y la fila lo dice con un radio en vez
de un check.

## Flujo de usuario

1. El trabajador abre su obra y toca el tab **Fotos**.
2. Toca la acción primaria —`FieldActionButton`, 64dp, se pulsa con guantes— y se
   abre la cámara.
3. Vuelve de la cámara y elige la etiqueta **en la misma pantalla**, sin paso
   extra. **No se puede saltar**: guarda con su etiqueta o descarta la foto.
4. La foto aparece en la grilla al instante, con su marca de "guardado en el
   teléfono" hasta que sube.
5. William, desde la misma grilla, abre una foto y la sube **un** escalón.

### La calidad no es la del marcaje

`ImagePickerPhotoCapture` está acotada a 2048px y 85% con un comentario que lo
dice: *"es evidencia, no portafolio"*. Estas fotos son lo contrario — son las
candidatas a `PUBLIC` y a los pares antes/después, y terminan en la web de William
y en sus redes, donde se ven grandes.

| Origen | Resolución | Peso aproximado |
|---|---|---|
| Marcaje | 2048px · 85% | ~0,5 MB |
| **Obra** | **3024px · 90%** | **~1,5 MB** |

`PhotoCapture` recibe la calidad como parámetro en vez de tenerla fija. Pesa el
triple, y eso alimenta la decisión abierta sobre cuánto se conserva en el
teléfono — no son dos temas separados.

## Contrato de API

Un endpoint nuevo y un endpoint que se endurece.

```http
POST /api/media/:id/tags
Permiso: media.capture

{ "tags": ["BEFORE", "DETAIL"] }
→ 200  MediaAssetDto
```

**`RegisterAssetDto` acepta `tags` también.** Al tomar la foto, la etiqueta va
adentro del registro y no como una segunda operación: son un solo gesto, y una
operación sola no puede quedar a medias. El endpoint dedicado queda para
corregir después.

```http
DELETE /api/media/:id
Permiso: media.delete
→ 204
```

Reemplaza el conjunto entero en vez de agregar de a una: quitar una etiqueta sin
señal necesitaría una operación de borrado propagable, y mandar el set completo la
vuelve idempotente sin nada extra (regla 19).

**La respuesta se declara como DTO.** `MediaAsset` no tiene hoy relación a sus
etiquetas ni en la entity ni en `openapi.json`, y devolver `{ ...asset, tags }` a
mano sale al spec como `{"type":"object"}` sin propiedades: el cliente Dart lo tipa
`dynamic`, parsea, descarta y **no falla** (regla 8). Va un `MediaAssetDto` con
`tags: MediaTagKind[]`, y es el mismo que devuelven los demás handlers de media.

```http
POST /api/media/:id/visibility
```

Suma la validación de la escalera: subir es de a un escalón, bajar no se
restringe. El rechazo lleva código propio y estable, `VISIBILITY_SKIPS_STEP`,
porque el cliente necesita distinguirlo de los otros rechazos del mismo endpoint
(ADR-0011). Va con su caso en `requests/edge-cases/`, que es donde vive un request
por invariante.

En `/sync`:

- **Push**: operación `media.tag`, declarada en `SYNC_OPERATIONS` con su DTO y en
  `OPERATION_PERMISSION` con `media.capture` — el mismo permiso que la REST, o el
  lote se convierte en la puerta de atrás del guard.
- **Pull**: **no hay colección nueva.** Las etiquetas viajan dentro de
  `mediaAssets`, que ya baja con scope por rol. Ver arriba por qué.

`openapi.json` se regenera en el mismo commit (regla 8).

## UI

**Un tab más en la obra**, junto a Registro, Cuadrilla y Detalle — el patrón de
[[../0009-la-obra-como-lugar/README|SPEC-0009]], con la misma `key` que rearma los
tabs cuando cambian los permisos.

- **Grilla de tres columnas**, más nuevas primero. La miniatura es cuadrada; la
  foto no se recorta al abrirla.
- **El estado va en `StatusLine`, no en chip**: en una grilla, un chip por celda
  convierte cada foto en un globo. Ver la regla del naranja.
- **La etiqueta se ve sobre la miniatura**, con su icono. Nunca color solo.
- **Una sola acción primaria naranja**: tomar la foto.
- **Estado vacío con texto propio**: una obra sin fotos es lo normal el primer
  día, no un error.
- **Los dos temas desde el primer commit** (regla 23). Esta pantalla se usa en un
  techo con sol directo.
- **`en` y `es` en el mismo commit** (regla 24), incluidas las seis etiquetas.

## Criterios de aceptación

- [ ] Una foto tomada con el modo avión puesto queda visible en la galería de esa
      obra, con su etiqueta, sin ningún reintento manual.
- [ ] Al volver la red sube sola y la fila local pasa a `SYNCED`, sin que el
      trabajador toque nada.
- [ ] La foto del marcaje **no** aparece en la galería de la obra, y la de la obra
      **no** aparece en el registro de asistencia.
- [ ] Un `WORKER` no ve la acción de subir de nivel en ninguna parte de la
      pantalla, y el `OWNER` sí.
- [ ] La misma foto registrada dos veces por un reintento no duplica la fila: el
      checksum la desduplica.
- [ ] `captured_at` es la hora de la foto, no la de la subida, y la grilla ordena
      por ella.
- [ ] Etiquetar sin señal y volver a etiquetar la misma foto deja un solo conjunto
      de etiquetas, no dos.
- [ ] Una etiqueta puesta en un teléfono aparece en otro después de sincronizar:
      cambiar las etiquetas toca `media_asset.updated_at` y por eso entra en el
      pull incremental.
- [ ] `INTERNAL → PUBLIC` en una sola llamada se rechaza con
      `VISIBILITY_SKIPS_STEP`, y bajar de nivel sigue sin restricción.
- [ ] Con el permiso de cámara denegado la pantalla explica qué falta y ofrece los
      ajustes, en vez de un botón que no hace nada.
- [ ] Una foto que no sube se ve como no subida, y nunca se descarta sola.
- [ ] La respuesta de `POST /media/:id/tags` sale en `openapi.json` con sus
      propiedades, no como `{"type":"object"}`.
- [ ] Un `WORKER` no puede borrar una foto, y el `OWNER` sí.
- [ ] Borrar la deja fuera de la galería en las dos puntas, y la baja llega a
      otro teléfono por el pull.
- [ ] Una foto que ya no está en el teléfono se ve igual con señal, y sin señal
      lo dice en vez de mostrar un cuadro roto.
- [ ] Ninguna pantalla de este frente importa un cliente de `lib/api/`
      (`api_isolation_test.dart`).
- [ ] La pantalla se ve completa en claro y en oscuro, y en los dos idiomas.
- [ ] Una foto recién tomada no se puede guardar sin etiqueta, y la hoja no se
      esquiva: ni deslizando ni con el atrás del sistema. Se guarda o se descarta.
- [ ] Descartar borra el binario del teléfono y no deja fila que sincronizar.
- [ ] Corregir la etiqueta de una foto anterior al 2026-08-30 que tenía varias no
      pierde ninguna sin que la persona lo vea: se muestran todas puestas, y
      tocar una es lo que las reemplaza.
- [ ] Cada cambio de nivel se confirma antes, incluida la bajada: lo que sale de
      la empresa no se des-ve.
- [ ] `openapi.json` regenerado y el cliente Dart al día.

## Riesgos / consideraciones

- **El peso en el teléfono.** Conservar los binarios para que la galería funcione
  sin señal es lo que la vuelve útil y también lo que llena el disco. Es la
  decisión abierta de arriba y conviene cerrarla antes de implementar, no después.
- **Ver las fotos de otros exige red.** Se sirven con URL firmada de vida corta
  (ADR-0010) y el bucket no es público. Cachearlas es otro spec; acá se muestra el
  estado con honestidad en vez de un error.
- **La escalera se endurece en este spec**, y eso puede romper un flujo que hoy
  funciona: cualquier consumidor que subiera de `INTERNAL` a `PUBLIC` de una vez
  empieza a recibir `VISIBILITY_SKIPS_STEP`. No hay datos reales ni `apps/web`
  todavía, así que el radio es el propio móvil y los `.bru`, pero el spec de
  publicación tiene que contar con que llegar a `PUBLIC` son dos pasos.
- **Queda sin aplicar en la base.** La validación entra en el servicio, no como
  trigger. Es una decisión consciente: el orden depende del estado anterior de la
  fila y un trigger que lo mire es más caro de mantener que el chequeo del
  servicio. El invariante duro de la base sigue siendo el EXIF (regla 17).
- **El pull con muchas fotos.** `GET /sync?since=` trae `mediaAssets` sin paginar.
  Una obra de dos semanas con dos cuadrillas puede ser un lote grande en la
  primera sincronización de un teléfono nuevo.

## ADRs relacionados

- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — el contrato se genera, `lib/api/` no se edita
- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]] — Drift, Riverpod y la bandeja de salida
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — tokens, los dos temas y las dos alturas de acción
- [[../../../adr/0010-backblaze-b2-para-fotos/README|ADR-0010]] — bucket privado y URL firmada

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-12 | borrador | Creado. Desbloqueado por DEBT-0005: publicar dejó de exigir un permiso que no se podía otorgar |
| 2026-08-13 | en-implementacion | El alcance creció probando en el teléfono: entra borrar una foto —con permiso propio `media.delete`— y la carga remota por URL firmada, que el spec daba por resuelta sin estarlo |
| 2026-08-12 | review | Tres bloqueantes del `spec-reviewer`. `media_tag` no puede sincronizar como colección propia —le faltan `updated_at` y `deleted_at`—, así que las etiquetas pasan a viajar dentro del asset. La escalera de visibilidad se endurece acá en vez de quedar como riesgo. Y el comportamiento sin señal suma los tres casos de falla que no eran de red |
| 2026-08-30 | en-implementacion | Segunda tanda, salida de probar en el teléfono: etiquetar pasa a ser obligatorio y de a una sola, se puede descartar una foto recién tomada, cada cambio de nivel se confirma, y el copy deja de explicar el sistema. Se arregla además que volver la red no sincronizaba con la obra abierta — Riverpod 3 pausa los listeners de los widgets tapados |
