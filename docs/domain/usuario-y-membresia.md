---
id: DOM-usuario-y-membresia
title: "Usuario y Membresía"
aliases: ["Usuario y Membresía"]
type: domain
status: borrador
related_specs: ["SPEC-0011"]
related_adrs: []
created: 2026-08-08
updated: 2026-09-03
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
| `password_hash` | string | no | Nulo hasta que la persona canjea su invitación y la elige |
| `name` | string | sí | |
| `locale` | string | sí | `en` o `es`. **Por usuario, no por empresa** |

### `membership`

| Atributo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `user_id` | uuid | sí | |
| `role` | enum | sí | Ver tabla abajo |
| `pay_rate_cents` | int | no | Tarifa por hora vigente |
| `employment_type` | enum | no | `W2` o `CONTRACTOR_1099` |
| `status` | enum | sí | `INVITED`, `ACTIVE`, `INACTIVE`. Solo una `ACTIVE` resuelve sesión |
| `token_version` | int | sí | Arranca en 0. Sube al cerrar sesión; un refresh con la versión vieja se rechaza. **Nunca lo manda el cliente** |
| `invite_code_hash` | string | no | El código que se dicta en persona, hasheado. Nulo cuando no hay invitación viva |
| `invite_expires_at` | timestamptz | no | Siete días desde que se emite |
| `invite_attempts` | int | sí | Arranca en 0. Se bloquea a los 10 y solo lo destraba emitir uno nuevo |

## Roles

| Rol | Qué puede |
|---|---|
| `OWNER` | Todo. William |
| `ADMIN` | Todo menos la facturación de la cuenta. La persona de oficina |
| `FOREMAN` | Marcar por quien fue a su obra ese día —el criterio es la obra, no la cuadrilla, ver [[registro-de-tiempo]]—, fotos, ver su proyecto |
| `WORKER` | Marcar entrada y salida, ver sus propias horas, tomar fotos. Nada más |
| `ACCOUNTANT` | Solo lectura de reportes y comercial. **Cero acceso a fotos** |

## Invariantes

- **`pay_rate_cents` solo lo ven `OWNER` y `ADMIN`.** Es lo que gana cada
  persona, y la membresía viaja embebida en cuadrillas y asignaciones que ven
  otros roles: en el API va con `select: false` y fuera del contrato, y quien lo
  necesita —aprobar congela la tarifa— lo selecciona explícito. Nunca baja al
  teléfono, con ningún rol.

- `email` o `phone`: al menos uno. No pueden ser ambos nulos.

- **Un `app_user` con `password_hash` nulo no inicia sesión por ningún camino.** Es
  quien fue invitado y todavía no canjeó. `bcrypt.compare` con un nulo no es una
  comparación fallida sino un error de tipo, así que el camino de login lo ataja
  antes de comparar: se cuela como 500 en vez de 401.

- **La contraseña es del usuario, no de la membresía.** Una persona con dos
  contratistas tiene una sola: no se la vuelve a pedir al canjear la segunda
  invitación, y **no se nulea mientras tenga otra membresía activa que la esté
  usando**. Regenerar el código de una empresa no puede dejarla sin entrar a la otra.

- **El código de invitación es de un solo uso y se guarda hasheado**, con bcrypt y no
  con sha256: seis dígitos son un millón de preimágenes que se precomputan en
  segundos. Lo que lo sostiene son tres cosas juntas —el identificador, el
  vencimiento y el corte por intentos—; si una se cae, el código queda adivinable y
  nada avisa.
- Una empresa tiene **exactamente un** `OWNER` activo.
- Un `WORKER` no puede aprobar sus propias horas ni modificar su `pay_rate_cents`.
  Ni siquiera el suyo propio, ni siquiera para bajarlo.
- Cambiar `pay_rate_cents` **no** afecta registros de tiempo ya aprobados: la
  tarifa se congela al aprobar. Ver [[registro-de-tiempo]].
- El `locale` vive en `user`, no en `membership`: la persona habla un idioma, no
  uno por empresa.

- **`token_version` es la única forma de que un refresh token deje de servir antes
  de vencer.** El refresh es un JWT autofirmado y sin estado: una vez emitido, vale
  30 días y el servidor no tiene dónde anotarlo. El contador viaja en el claim y se
  compara al refrescar; si no coincide, el token se rechaza aunque su firma sea
  válida. Lo escribe el servidor y **nunca se acepta del cliente**.

  **Un claim ausente cuenta como 0**, porque los tokens emitidos antes de que el
  campo existiera no lo llevan y compararlos con igualdad estricta los invalidaría a
  todos de golpe.

  **Vive en la membresía, así que la invalidación es por membresía y no por
  dispositivo.** Subirlo cierra todas las sesiones de esa persona en esa empresa —
  el panel y el teléfono a la vez. Separarlas exigiría una tabla de sesiones, que no
  existe. Ver [[../specs/web/0008-sesion-y-shell/README|SPEC-0008]].

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
`membership`, con roles y tarifas distintas. Su `locale` es el mismo en ambas, y su
contraseña también: canjear la invitación del segundo contratista activa esa
membresía y no le pide una nueva.

**Borde** — Alguien que se fue y volvió la temporada siguiente. Se reactiva **la misma
membresía**, con el rol y la tarifa que traiga el alta nueva: sus horas viejas y su
pertenencia terminada a una cuadrilla siguen apuntando a la misma fila.
