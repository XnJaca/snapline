---
id: DEBT-0012
title: "Relaciones de entity que el servidor nunca manda salen al contrato como requeridas"
aliases:
  - "DEBT-0012: Relaciones de entity que el servidor nunca manda salen al contrato como requeridas"
type: tech-debt
status: abierta
severity: alta
origin: "SPEC-0012"
apps:
  - api
  - mobile
trigger: "El primer consumidor de billing o de publishing — el panel de Angular o el sitio de Astro, el que llegue antes"
created: 2026-09-03
updated: 2026-09-03
tags:
  - tech-debt
  - contrato
---

# DEBT-0012: Relaciones de entity que el servidor nunca manda salen al contrato como requeridas

## Contexto

El plugin de Swagger introspecciona las entities, y una relación `@ManyToOne`
sin decorador sale a `openapi.json` como propiedad **requerida y no nullable**.
El servidor no la serializa —manda solo el `*Id` que produce `@RelationId`—, así
que el cliente generado exige un objeto que nunca llega.

En Dart el resultado es un cast duro:

```dart
project: Project.fromJson(json['project'] as Map<String, dynamic>),
```

Con `project` ausente, eso lanza `type 'Null' is not a subtype of type
'Map<String, dynamic>'` y **se cae el parseo de la respuesta entera**, no solo
del campo. Si el objeto viaja dentro del pull, el dispositivo deja de
sincronizar todo.

Una relación **nullable** no tiene el problema: el schema la marca
`nullable: true` y el generador produce `json['x'] == null ? null : ...`. Por eso
`Crew.foreman` convive con el defecto sin romperse.

## Cómo apareció

`ProjectUpdate` tenía sus tres relaciones sin decorar. La entity existía desde el
portal del cliente, donde su respuesta se armaba a mano y nunca pasaba por el
cliente generado. SPEC-0012 la sumó al pull, y el defecto se volvió un pull caído
en el teléfono: 200 del servidor, excepción en el dispositivo.

Se arregló marcando las tres con `@ApiPropertyOptional()`, que es lo que ya hacían
`Project.customer`, `Project.site` y `ProjectStatusChange.changedBy`.

## Qué queda abierto

El mismo defecto vive en otras veinte propiedades. Ninguna rompe hoy porque
**ningún cliente las parsea todavía**:

| Schema | Propiedades |
|---|---|
| `Estimate`, `EstimateLine` | `customer`, `estimate` |
| `Invoice`, `InvoiceLine`, `Payment` | `customer`, `invoice` |
| `Testimonial`, `PublishedProject`, `BeforeAfterPair`, `SocialPost` | `project`, `customer`, `heroAsset`, `beforeAsset`, `afterAsset` |
| `Membership` | `user` |

`AuthResultDto.user`, `Site.address` y `RegisterAssetResponseDto.asset` también
figuran, pero ahí **el servidor sí manda el objeto**: son correctas.

### `Membership.user` ya tiene quien lo dispare

No es hipotético como el resto: **`crews.service.ts` hace el eager-load que lo
activa**. `list()` y `get()` cargan `relations: { foreman: true }` sin
`foreman.user`, y `listMembers()` carga `relations: { membership: true }` sin
`membership.user`. Un cliente generado que llame `GET /crews`, `GET /crews/:id`
o `GET /crews/:id/members` con una cuadrilla que tenga capataz asignado revienta
con el mismo `type 'Null' is not a subtype`.

Hoy no rompe porque el móvil arma las cuadrillas desde `/sync`, cuya query nunca
hace ese join —así que el campo llega ausente y el tipo es nullable de verdad— y
ningún repositorio ni pantalla llama al `CrewsClient`. Explota el día que Angular
consuma `GET /crews` con los tipos generados.

## Workaround actual

Ninguno. El defecto está latente: el día que Angular o Astro consuman billing o
publishing con tipos generados, van a fallar igual y de la misma forma.

## Cómo se cierra

Recorrer las entities de `billing/`, `publishing/` y `auth/`, y decidir por
relación: `@ApiPropertyOptional()` si alguna respuesta la carga, o
`@ApiHideProperty()` si no viaja nunca. Regenerar el contrato y verificar que
`required` no tenga ninguna relación no-nullable que el servidor no serialice.

La verificación se puede automatizar — es la consulta que encontró esta lista:
cruzar `required` con las propiedades que son `$ref` y no son `nullable`.
Es candidata a chequeo de `contract-watcher`.

## Por qué no se hizo ahora

Toca cuatro módulos fuera del alcance de SPEC-0012, y tres de ellos —catalog,
crews, billing y reports— son la deuda declarada del `CLAUDE.md`: se construyeron
sin spec. Arreglarles el contrato sin entender qué respuesta carga qué relación
es adivinar.
