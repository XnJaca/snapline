---
id: SPEC-0010
title: "Fotos de la obra"
aliases:
  - "SPEC-0010: Fotos de la obra"
type: spec
platform: mobile
status: borrador
goal: "Una foto tomada en la obra sin señal aparece etiquetada en la galería de esa obra, sube sola cuando vuelve la red, y solo OWNER o ADMIN pueden subirla de nivel."
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
updated: 2026-08-12
tags:
  - spec
  - spec/borrador
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
  el permiso.
- **En `apps/api`: `POST /media/:id/tags`**, que hoy no existe — `media_tag` tiene
  tabla y entity y ningún endpoint. Entra acá por la misma razón que
  [[../0006-clientes-en-el-movil/README|SPEC-0006]] trajo `site.update`: es este
  spec el que lo necesita.
- **En `apps/api`: `mediaTags` en el pull de `/sync`** y la operación `media.tag`
  en el push, o la etiqueta puesta sin señal no llega nunca.

### No entra

- **Publicar la obra.** El botón que llama a `POST /projects/:id/publish` va en su
  propio spec. Este deja el material listo y etiquetado; publicarlo es una acción
  deliberada de William y merece su propia pantalla.
- **Armar el par antes/después.** Su endpoint ya existe
  (`POST /projects/:id/before-after`) y la etiqueta que lo alimenta sale de acá,
  pero elegir cuál con cuál es del spec de publicación.
- **Editar la foto.** Recorte y filtros son otra categoría, y la ficha de
  [[contenido]] ya lo declara fuera.
- **Borrar una foto.** Necesita borrado suave propagable (regla 20) y no hay caso
  de uso pedido todavía.
- **Documentos.** `kind = DOCUMENT` y su `document_kind` no se capturan desde el
  teléfono en este alcance.

## Modelo de dominio afectado

- [[contenido]] — `media_asset`, `media_tag` y la escalera de visibilidad
- [[proyecto]] — de dónde cuelgan las fotos

**No agrega ningún agregado ni campo nuevo al servidor.** Todo lo que este spec
necesita ya está en el esquema desde la migración inicial; lo que falta es
exponerlo y consumirlo.

### Lo que sí cambia en la base local

| Tabla Drift | Cambio | Por qué |
|---|---|---|
| `MediaAssets` | **Nueva** | Hoy una foto registrada solo vive en `pending_uploads` hasta que sube, y después desaparece del teléfono. Sin tabla no hay galería offline |
| `MediaTags` | **Nueva** | Un asset tiene varias etiquetas; guardarlas como fila y no como JSON deja el filtro por etiqueta en una consulta |
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

> **Decisión pendiente de la implementación:** cuánto se conserva. Un mes de fotos
> de dos cuadrillas no es trivial en un teléfono de trabajo. Si aparece un número
> defendible se registra acá; si no, va a `/debt-new` con su trigger.

## Flujo de usuario

1. El trabajador abre su obra y toca el tab **Fotos**.
2. Toca la acción primaria —`FieldActionButton`, 64dp, se pulsa con guantes— y se
   abre la cámara.
3. Vuelve de la cámara y elige la etiqueta **en la misma pantalla**, sin paso
   extra. Se puede saltar: una foto sin etiqueta entra igual.
4. La foto aparece en la grilla al instante, con su marca de "guardado en el
   teléfono" hasta que sube.
5. William, desde la misma grilla, abre una foto y la sube de nivel.

## Contrato de API

Un endpoint nuevo. El resto ya existe y no se toca.

```http
POST /api/media/:id/tags
Permiso: media.capture

{ "tags": ["BEFORE", "DETAIL"] }
→ 200  MediaAsset con sus etiquetas
```

Reemplaza el conjunto entero en vez de agregar de a una: quitar una etiqueta sin
señal necesitaría una operación de borrado propagable, y mandar el set completo la
vuelve idempotente sin nada extra (regla 19).

En `/sync`:

- **Push**: operación `media.tag`, con su DTO validado como las demás.
- **Pull**: colección `mediaTags`, con el mismo scope por rol que `mediaAssets`.

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
- [ ] Ninguna pantalla de este frente importa un cliente de `lib/api/`
      (`api_isolation_test.dart`).
- [ ] La pantalla se ve completa en claro y en oscuro, y en los dos idiomas.
- [ ] `openapi.json` regenerado y el cliente Dart al día.

## Riesgos / consideraciones

- **El peso en el teléfono.** Conservar los binarios para que la galería funcione
  sin señal es lo que la vuelve útil y también lo que llena el disco. Es la
  decisión abierta de arriba y conviene cerrarla antes de implementar, no después.
- **Ver las fotos de otros exige red.** Se sirven con URL firmada de vida corta
  (ADR-0010) y el bucket no es público. Cachearlas es otro spec; acá se muestra el
  estado con honestidad en vez de un error.
- **La escalera `INTERNAL → CLIENT → PUBLIC` no está aplicada en ningún lado.**
  Hoy se salta a `PUBLIC` directo, en el servicio y en la base. Es anterior a este
  spec y quedó anotado al cerrar DEBT-0005; si la pantalla ofrece los tres niveles,
  conviene decidir si el orden se aplica o se acepta el salto.
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
