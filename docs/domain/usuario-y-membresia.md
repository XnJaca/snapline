---
id: DOM-usuario-y-membresia
title: "Usuario y Membresía"
aliases: ["Usuario y Membresía"]
type: domain
status: borrador
related_specs: []
related_adrs: []
created: 2026-08-08
updated: 2026-08-08
tags: [domain, domain/borrador]
---

# Usuario y Membresía

## Qué es

**Usuario** es la cuenta de una persona. **Membresía** es esa persona dentro de una
empresa, con su rol y su tarifa. Son dos cosas porque una persona puede trabajar
para más de un contratista.

## Atributos

### `user`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `email` | string | no | Único si existe |
| `phone` | string | no | Único si existe. Muchos trabajadores no usan email |
| `password_hash` | string | sí | |
| `name` | string | sí | |
| `locale` | string | sí | `en` o `es`. **Por usuario, no por empresa** |

### `membership`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `user_id` | uuid | sí | |
| `role` | enum | sí | Ver tabla abajo |
| `pay_rate_cents` | int | no | Tarifa por hora vigente |
| `employment_type` | enum | no | `W2` o `1099` |
| `status` | enum | sí | `invitado`, `activo`, `inactivo` |

## Roles

| Rol | Qué puede |
|---|---|
| `OWNER` | Todo. William |
| `ADMIN` | Todo menos la facturación de la cuenta. La persona de oficina |
| `FOREMAN` | Su cuadrilla: marcar por su gente, fotos, ver su proyecto |
| `WORKER` | Marcar entrada y salida, tomar fotos. Nada más |
| `ACCOUNTANT` | Solo lectura de reportes y comercial. **Cero acceso a fotos** |

## Invariantes

- `email` o `phone`: al menos uno. No pueden ser ambos nulos.
- Una empresa tiene **exactamente un** `OWNER` activo.
- Un `WORKER` no puede aprobar sus propias horas ni modificar su `pay_rate_cents`.
  Ni siquiera el suyo propio, ni siquiera para bajarlo.
- Cambiar `pay_rate_cents` **no** afecta registros de tiempo ya aprobados: la
  tarifa se congela al aprobar. Ver [[registro-de-tiempo]].
- El `locale` vive en `user`, no en `membership`: la persona habla un idioma, no
  uno por empresa.

## Comportamiento offline

La membresía se cachea en el dispositivo para saber qué puede hacer el usuario sin
red. **Los permisos se verifican igual en el servidor** al sincronizar: el caché
local es conveniencia de UI, nunca autoridad.

## Eventos que emite

- `UsuarioInvitado`, `MembresiaActivada`, `RolCambiado`, `TarifaActualizada`

## Relaciones con otros agregados

- [[empresa]] — pertenece a
- [[cuadrilla]] — un `WORKER` o `FOREMAN` pertenece a cuadrillas con fechas
- [[registro-de-tiempo]] — sus horas

## Qué NO es

- **No incluye al cliente final.** Ese entra por token y vive en [[acceso-del-cliente]].
- No maneja permisos granulares por recurso. El rol es el permiso.
- No guarda historial de tarifas: para eso está el congelado en el registro de tiempo.

## Ejemplos

**Típico** — Un `WORKER` con teléfono, sin email, `locale: es`, tarifa por hora.

**Borde** — Una persona que trabaja para dos contratistas: un `user`, dos
`membership`, con roles y tarifas distintas. Su `locale` es el mismo en ambas.
