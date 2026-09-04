---
id: DOM-contenido
title: "Contenido"
aliases: ["Contenido"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0004"]
created: 2026-08-08
updated: 2026-09-01
tags: [domain, domain/borrador]
---

# Contenido

## Qué es

Las fotos, videos y documentos de un proyecto, y quién puede verlos.

Es el activo del producto: de acá sale lo que se publica y lo que alimenta las redes.

## Atributos

### `media_asset`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `project_id` | uuid | sí | |
| `kind` | enum | sí | `PHOTO`, `VIDEO`, `DOCUMENT` |
| `storage_key` | string | sí | Clave en el bucket de B2 |
| `mime` / `bytes` / `width` / `height` | | sí | |
| `captured_at` | timestamptz | no | **Del EXIF**, no de cuándo subió |
| `uploaded_by` | uuid | sí | |
| `device_lat` / `device_lng` | numeric | no | Dónde se tomó |
| `checksum` | string | sí | Para desduplicar reintentos |
| `exif_stripped_at` | timestamptz | no | **Habilita `PUBLIC`** en una foto |
| `upload_status` | enum | sí | `pendiente`, `subiendo`, `listo`, `fallido` |
| `visibility` | enum | sí | `INTERNAL` (default), `CLIENT`, `PUBLIC` |
| `document_type` | enum | no | Si es documento: contrato, permiso, plano, seguro, W-9, recibo |

### `media_tag`

`BEFORE` · `DURING` · `AFTER` · `DETAIL` · `PROBLEM` · `RECEIPT`

### `before_after_pair`

`before_asset_id`, `after_asset_id`, `caption`. Tabla propia porque es **la** pieza
de marketing del producto, no una foto más.

## Invariantes

- **La visibilidad es una escalera**: `INTERNAL` → `CLIENT` → `PUBLIC`. No se salta.
- **Sube por dos caminos, no uno.** El directo, elevando el asset; y como efecto
  de marcar una nota de obra para el cliente, que eleva a `CLIENT` las fotos que
  adjuntó y estaban en `INTERNAL` — un escalón, nunca hasta `PUBLIC`. El segundo
  existe porque el portal descarta en silencio las fotos que no son `CLIENT`: sin
  elevarlas, la nota le llega al cliente sin ninguna. Ver [[proyecto]].
- **`PUBLIC` exige `exif_stripped_at` no nulo en las fotos**, y la restricción vive
  en la base de datos. Las fotos llevan coordenadas GPS; publicarlas expone la
  dirección exacta de la vivienda de un cliente. La app captura ubicación a
  propósito, así que el riesgo es concreto.
- **Quién publica es la empresa, no el cliente.** No hay permiso del cliente que
  habilite `PUBLIC`; decidido el 2026-08-12, ver [[../DECISIONES]].
- **Las URLs son firmadas y de vida corta.** El bucket no es público: si lo fuera,
  las fotos de las casas de los clientes estarían en internet abierto para quien
  adivine la ruta.
- `captured_at` sale del EXIF, no de la subida. Con offline la diferencia puede ser
  de días, y el orden cronológico del proyecto depende de esto.
- `checksum` evita que un reintento de subida duplique la foto.
- Un portador de token de cliente no puede pedir un asset `INTERNAL`.
- El tipo y el tamaño se validan **en el servidor**, no solo en el cliente.

## Comportamiento offline

Caso de uso central. La foto se guarda local con UUIDv7, entra a la bandeja de
salida y sube por partes cuando hay red. `upload_status` refleja el progreso.

Si la app se cierra a mitad de la subida, se retoma por `checksum`, no se reinicia.
El asset existe en el dispositivo desde el momento del disparo, no desde que subió.

## Eventos que emite

- `AssetCapturado`, `AssetSubido`, `VisibilidadElevada`, `ParAntesDespuesCreado`,
  `AssetDespublicado`

## Relaciones con otros agregados

- [[cliente]] — de quién es la obra que se ve en la foto
- [[registro-de-tiempo]] — la foto de marcaje es un asset
- [[publicacion]] — qué sale al portafolio
- [[acceso-del-cliente]] — qué ve el cliente
- [[proyecto]] — de dónde cuelga. Y su bitácora **escribe** sobre la visibilidad
  de estos assets al publicar una nota: es la única relación de este agregado que
  no es de solo lectura

## Qué NO es

- No es un gestor de archivos general. Todo asset pertenece a un proyecto.
- No hace edición de imagen. Recorte y filtros son de otra categoría.
- No decide qué se publica: eso es [[publicacion]]. Acá solo vive el nivel de acceso.

## Ejemplos

**Típico** — 40 fotos de un techo, `INTERNAL`. William marca 8 como `CLIENT` y 3
como `PUBLIC` al terminar. Arma un par antes/después con dos de ellas.

**Borde** — Foto tomada sin señal a las 9:00, subida a las 18:00. `captured_at` es
9:00 y aparece en el orden correcto de la obra, no al final del día.

**Borde hostil** — Un endpoint nuevo pasa una foto a `PUBLIC` sin haberle limpiado
el EXIF. La base de datos lo rechaza, no el formulario: publicarla dejaría las
coordenadas de la casa del cliente en el portafolio.
