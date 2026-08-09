---
id: DOMAIN-INDEX
title: "Modelo de dominio — Índice"
type: index
tags:
  - index
  - domain
---

# Modelo de dominio

De acá sale el esquema de Postgres. Definido antes de escribir migraciones a
propósito: migrar con datos reales adentro cuesta cinco veces más.

**Alcance completo, no de la primera entrega.** El esquema se construye entero; lo
que se parte por fases son las pantallas. Ver [[../product/roadmap|roadmap]].

## Reglas que aplican a todos los agregados

No se repiten en cada ficha. Se dan por sentadas en todas.

1. **`company_id` en toda tabla.** Sin excepción, y el scope va en el repositorio,
   no en cada query. Una query sin scope de tenant es fuga entre contratistas
   competidores.
2. **IDs UUIDv7 generados en el cliente.** Sin esto no hay offline real: el
   dispositivo crea el registro con su ID definitivo y no hay que reconciliar IDs
   temporales al sincronizar. Además ordenan por tiempo, así que sirven como clave
   primaria sin fragmentar el índice.
3. **Dinero en enteros de centavos.** Nunca punto flotante. Columna con sufijo
   `_cents`, siempre.
4. **`timestamptz` en UTC.** La empresa guarda su zona (`America/New_York`). Todo
   lo capturado en campo guarda **dos** tiempos: `device_recorded_at` y
   `server_received_at`. Nunca son el mismo con señal intermitente.
5. **Borrado suave** (`deleted_at`) en todo lo que sincroniza a móvil. Un borrado
   duro no se puede propagar a un dispositivo que estuvo sin señal.
6. **`updated_at` en todo**, y es el cursor de sincronización.
7. **Escrituras idempotentes.** Toda mutación desde móvil lleva clave de
   idempotencia: la red se cae a mitad de un POST y el reintento no puede duplicar.

## Sincronización

El móvil mantiene una bandeja de salida local y la reproduce en orden. El servidor
resuelve por **última escritura gana**, con una excepción:
[[registro-de-tiempo]], donde un conflicto **no se resuelve solo** — se marca y lo
revisa un humano. Las horas de alguien no se sobrescriben en silencio.

## Mapa

![[mapa-dominio.excalidraw]]

Cada caja enlaza a su ficha: Cmd+click para abrirla. Requiere el plugin Excalidraw;
sin él se ve como un archivo cualquiera.

## Agregados

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], title)) AS "Agregado",
  status AS "Estado",
  related_specs AS "Specs que lo tocan"
FROM "domain"
WHERE type = "domain"
SORT title ASC
```

### Por área

| Área | Agregados |
|---|---|
| Tenencia y personas | [[empresa]] · [[usuario-y-membresia]] · [[cuadrilla]] |
| Clientes y obra | [[cliente]] · [[proyecto]] |
| Campo | [[registro-de-tiempo]] · [[contenido]] |
| Comercial | [[catalogo-de-servicios]] · [[estimado]] · [[factura]] |
| Cliente final | [[acceso-del-cliente]] · [[oferta-y-lead]] |
| Publicación | [[publicacion]] |

## Lo que falta decidir

- [ ] Tasa y tratamiento de sales tax en Maryland — lo confirma el contador de William
- [ ] Si el foreman puede editar horas de su cuadrilla o solo registrarlas
- [ ] Retención de fotos: cuánto se guarda el original a resolución completa
- [ ] Si un cliente con cuenta ve todos sus proyectos históricos o solo el activo

Crear un agregado nuevo con `/domain-new <nombre>`. **Se le agrega su caja al mapa
en el mismo acto** — un agregado que no está en el mapa es un agregado que nadie ve.
