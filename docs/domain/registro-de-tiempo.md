---
id: DOM-registro-de-tiempo
title: "Registro de Tiempo"
aliases: ["Registro de Tiempo"]
type: domain
status: borrador
related_specs: []
related_adrs: ["ADR-0003"]
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Registro de Tiempo

## Qué es

La entrada y salida de un trabajador en un proyecto, con la evidencia de que
estuvo ahí.

> **El agregado más delicado del sistema.** Es evidencia laboral: alimenta el pago
> de una persona y puede terminar en una disputa. Todo lo demás se puede corregir;
> esto se defiende.

## Atributos

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `project_id` / `membership_id` | uuid | sí | |
| `clock_in_at` / `clock_out_at` | timestamptz | in sí | |
| `break_minutes` | int | no | |
| `*_lat` / `*_lng` | numeric | no | Por cada marca |
| `*_accuracy_m` | int | no | Precisión reportada por el dispositivo |
| `*_distance_m` | int | no | **Calculada en el servidor** |
| `*_within_geofence` | bool | no | **Derivada en el servidor** |
| `*_photo_id` | uuid | no | |
| `method` | enum | sí | `SELF`, `FOREMAN`, `ADMIN` |
| `recorded_by_membership_id` | uuid | sí | Quién marcó — no siempre es de quién es la hora |
| `device_id` | string | no | |
| `is_mock_location` | bool | sí | |
| `recorded_offline` | bool | sí | |
| `device_recorded_at` | timestamptz | sí | Lo que dijo el dispositivo |
| `server_received_at` | timestamptz | sí | Cuándo llegó de verdad |
| `status` | enum | sí | `PENDING` → `APPROVED` · `REJECTED` |
| `approved_by` / `approved_at` | | no | |
| `pay_rate_cents_snapshot` | int | no | Congelado al aprobar |
| `flags` | text[] | no | |

## Banderas

Las levanta el sistema, **sin bloquear a nadie**: fuera de geocerca, sin foto, GPS
simulado, jornada mayor a 14 horas, sin marca de salida, editado a mano, dos
proyectos solapados, `device_recorded_at` fuera de rango razonable.

## Invariantes

Las cuatro que no se negocian:

- **Marcar nunca falla.** Sin red, sin GPS, sin permiso de cámara: se registra
  igual con lo que haya y se marca con bandera. Un trabajador que no puede fichar
  deja de usar la app el primer día.
- **`within_geofence` y `distance_m` se calculan en el servidor**, desde `lat`/`lng`
  contra las coordenadas del sitio. **Nunca se aceptan del dispositivo.** Si se
  confía en la bandera que manda el teléfono, el control de asistencia es decorativo.
- **`is_mock_location` se guarda siempre.** Android permite falsear el GPS con una
  app gratis; sin esa bandera la geocerca es teatro.
- **Nada se borra ni se sobrescribe.** Toda corrección deja rastro en
  `time_entry_edit` con quién, cuándo y valor anterior.

Además:

- La tarifa se congela en `pay_rate_cents_snapshot` **al aprobar**. Si sube el pago
  en octubre, las horas de septiembre no se recalculan.
- Un `WORKER` no aprueba sus propias horas. Nunca, ni las suyas ni las de otro.
- `device_recorded_at` lo provee el dispositivo, así que es dato manipulable: el
  servidor lo acota (no futuro, no más viejo que N días) y marca lo que se salga.
- No puede haber dos registros abiertos (sin `clock_out_at`) del mismo `membership`.

## Comportamiento offline

Es el caso de uso principal del offline: se crea en el dispositivo con UUIDv7 y se
encola. Sube cuando hay red, con `recorded_offline = true`.

**Un conflicto de sincronización acá no se resuelve solo** — se marca y lo revisa
un humano. Es la única excepción a "última escritura gana" del modelo. Las horas de
alguien no se sobrescriben en silencio.

## Eventos que emite

- `EntradaMarcada`, `SalidaMarcada`, `RegistroAprobado`, `RegistroRechazado`,
  `RegistroEditado`, `BanderaLevantada`

## Relaciones con otros agregados

- [[proyecto]] — dónde se trabajó
- [[usuario-y-membresia]] — de quién son las horas y de dónde sale la tarifa
- [[contenido]] — la foto de marcaje es un asset
- [[cuadrilla]] — el foreman puede marcar por los suyos

## Qué NO es

- **No calcula nómina.** Produce horas aprobadas y horas × tarifa. Retenciones,
  impuestos y pagos los hace el contador. Esa línea no se cruza.
- No hace tracking continuo: solo el punto de entrada y el de salida.
- No es un turno planificado. Lo planeado vive en la asignación del proyecto.
- No maneja horas extra ni reglas de overtime. Eso es cálculo de nómina.

## Ejemplos

**Típico** — Trabajador marca a las 7:02, dentro de la geocerca, con foto. Marca
salida a las 15:40. El admin aprueba y la tarifa queda congelada.

**Borde** — Sótano sin GPS ni señal: se registra con `lat`/`lng` nulos,
`recorded_offline = true`, y sube tres horas después. `device_recorded_at` dice
7:02, `server_received_at` dice 10:15. Levanta la bandera "sin ubicación" y el
admin decide. **La entrada existe y es válida.**

**Borde hostil** — El dispositivo manda `within_geofence: true` desde 40 km. El
servidor lo ignora, recalcula desde las coordenadas, marca fuera de geocerca, y si
además viene `is_mock_location: true` la bandera es doble.
