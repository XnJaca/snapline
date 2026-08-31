---
id: DEBT-0008
title: "Cerrar sesión en el panel también expulsa el teléfono"
aliases:
  - "DEBT-0008: Cerrar sesión en el panel también expulsa el teléfono"
type: tech-debt
status: abierta
severity: media
origin: "ADR-0014"
apps:
  - api
  - web
  - mobile
trigger: "La primera queja real de alguien que cerró sesión en la computadora y encontró la app del teléfono pidiéndole contraseña"
created: 2026-08-30
updated: 2026-08-30
tags:
  - tech-debt
  - tech-debt/abierta
  - seguridad
---

# DEBT-0008: Cerrar sesión en el panel también expulsa el teléfono

## Contexto

Sale de la decisión 3b del [[../adr/0014-sesion-web-en-cookie/README|ADR-0014]], que
resuelve un problema anterior: el refresh es un JWT autofirmado y sin estado, así que
*"cerrar sesión"* no podía significar más que "el cliente borró su copia". Un token
capturado antes del logout seguía valiendo 30 días.

`membership.token_version` lo arregla — el contador viaja en el claim y sube al
cerrar sesión, y un refresh con la versión vieja se rechaza.

## Qué no se hizo

**La invalidación es por membresía, no por dispositivo.** El contador es uno solo por
membresía, así que subirlo tira **todas** las sesiones de esa persona en esa empresa
a la vez.

Para William, que administra desde la computadora y usa la app parado en la obra, eso
significa que cerrar sesión al terminar el día de oficina le pide contraseña en el
teléfono a la mañana siguiente. Es el comportamiento correcto del mecanismo y aun así
se va a sentir como un bug.

Lo que faltaría es un registro por sesión —una tabla con una fila por dispositivo, su
propio identificador y su propia revocación—, de modo que el logout invalide solo la
sesión desde la que se pidió.

## Workaround actual

Ninguno del lado del usuario: si pasa, se vuelve a entrar.

Lo que sí acota el daño es que hoy **solo el panel tiene logout server-side**. El
móvil cierra sesión borrando sus tokens localmente y no toca el contador, así que la
expulsión cruzada solo ocurre en una dirección: del panel hacia el teléfono, nunca al
revés.

## Costo de resolverla

Un agregado nuevo. Tabla de sesiones con `company_id` (regla 6), su `revoked_at`, y
el `jti` del token emitido; el claim pasa a llevar el identificador de sesión en vez
del contador, y `refresh()` verifica contra la fila. Toca la ficha de
[[../domain/usuario-y-membresia|usuario-y-membresia]], una migración, y los dos
clientes si se quiere ofrecer "cerrar sesión en todos los dispositivos".

Hacerlo ahora, antes de tener una queja, es construir una tabla para un problema que
todavía no se sabe si molesta: hoy hay **un solo usuario real** y su patrón de uso no
está observado.

## Trigger

La primera queja real de alguien que cerró sesión en la computadora y encontró la app
del teléfono pidiéndole contraseña.

Un segundo disparador, si llega antes: que se pida *"cerrar sesión en todos los
dispositivos"* como función explícita. Ahí la tabla de sesiones deja de ser el costo
de arreglar esto y pasa a ser el camino para construir aquello.
