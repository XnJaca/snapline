---
id: DOM-publicacion
title: "Publicación"
aliases: ["Publicación"]
type: domain
status: borrador
related_specs: []
related_adrs: []
created: 2026-08-08
updated: 2026-08-12
tags: [domain, domain/borrador]
---

# Publicación

## Qué es

El proyecto terminado convertido en pieza pública: la entrada del portafolio en su
web, y el material del que sale el contenido de redes.

Es el cierre del ciclo y la premisa de venta del producto.

## Atributos

### `published_project`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `project_id` | uuid | sí | |
| `slug` | string | sí | Único por empresa |
| `title` / `summary` | string | sí | |
| `hero_asset_id` | uuid | sí | |
| `assets[]` | uuid[] | sí | Solo los `PUBLIC` |
| `service_type` / `city` | string | no | Filtros del portafolio y del feed |
| `testimonial_id` | uuid | no | |
| `published_at` / `unpublished_at` | timestamptz | | |

### `social_post`

| Atributo | Notas |
|---|---|
| `source_project_id`, `platform`, `content`, `assets[]` | |
| `status` | `sugerido`, `programado`, `publicado` |

Esta tabla es lo que vuelve repetible el servicio de redes: registra qué material
ya se usó, para no repetir el mismo antes/después en tres meses.

### `testimonial`

`customer_id`, `project_id`, `rating`, `body`, `approved_at`, `published_at`.
Enganchado al proyecto que lo originó — es la fase 3 que ya se le cotizó a William.

## Invariantes

- Solo entran assets en nivel `PUBLIC`, y con **EXIF limpio**: publicar las
  coordenadas GPS de la casa de un cliente es una fuga de privacidad real, no
  teórica. Es restricción de base de datos, en [[contenido]].
- **Se despublica, no se borra.** `unpublished_at` en vez de `DELETE`: el link ya
  está indexado y una URL que devuelve 404 de golpe es peor que una que explica.
- El `slug` es único por empresa y no cambia después de publicado.
- **Publicar no requiere permiso del cliente.** La decisión es de la empresa, que
  es quien hizo la obra; decidido el 2026-08-12, ver [[../DECISIONES]]. Si un
  cliente pide que bajen su obra, se despublica.
- Un testimonio no se publica sin `approved_at`.

## Comportamiento offline

Publicar requiere red. El botón se deshabilita sin conexión — es una acción
deliberada, no algo que deba encolarse y ejecutarse sola horas después.

## Eventos que emite

- `ProyectoPublicado`, `ProyectoDespublicado`, `TestimonioAprobado`,
  `ContenidoMarcadoComoUsado`

## Relaciones con otros agregados

- [[proyecto]] — qué se publica
- [[contenido]] — de dónde salen las fotos y qué nivel tienen
- [[cliente]] — su release habilita todo esto
- [[oferta-y-lead]] — el otro extremo del ciclo

## Qué NO es

- **No publica en redes automáticamente.** Prepara y registra el material; publicar
  en Instagram o Facebook lo hace una persona.
- No es un CMS. No se editan páginas arbitrarias del sitio.
- No mide tráfico ni analítica del sitio.

## Ejemplos

**Típico** — Proyecto terminado, ocho fotos `PUBLIC`, dos pares antes/después,
testimonio del cliente. Se publica con un botón y aparece en su web.

**Borde** — Cliente revoca el release seis meses después. El proyecto se despublica,
los assets bajan a `CLIENT`, y los `social_post` que lo usaban quedan marcados para
no reutilizarse.
