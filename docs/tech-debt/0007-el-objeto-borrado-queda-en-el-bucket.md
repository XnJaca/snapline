---
id: DEBT-0007
title: "Borrar una foto no libera el objeto en Backblaze"
aliases:
  - "DEBT-0007: Borrar una foto no libera el objeto en Backblaze"
type: tech-debt
status: abierta
severity: baja
origin: "SPEC-0010"
apps:
  - api
trigger: "Cuando el almacenamiento de B2 pase de lo que cueste mirar, o antes de la primera empresa que no sea la de William"
created: 2026-08-14
updated: 2026-08-14
tags:
  - tech-debt
  - tech-debt/abierta
  - publicacion
---

# DEBT-0007: Borrar una foto no libera el objeto en Backblaze

## Contexto

`DELETE /media/:id` hace **borrado suave**: la fila queda con `deleted_at` para
que la baja se pueda propagar a un teléfono que estuvo sin señal (regla 20). El
objeto en el bucket **no se toca**.

Es deliberado: mientras la fila exista, borrar el binario dejaría un registro
apuntando a nada, y no hay pantalla para restaurar una foto — así que el estado
"borrada pero con su archivo" es recuperable y el inverso no.

El costo es que **se sigue pagando el almacenamiento de algo que nadie va a
ver**. B2 cobra por GB guardado, que es justamente la partida que pesó al elegirlo
sobre R2 (ADR-0010).

## Por qué es severidad baja

Una foto de obra pesa ~1,5 MB. Borrar es una acción rara —se hace con la foto
movida o la que quedó huérfana— así que el desperdicio crece despacio. Con una
sola empresa y sin fotos reales todavía, hoy es cero.

Sube de severidad sola cuando haya varias empresas: el costo es de la
plataforma, no del cliente que borró.

## Qué hay que hacer

Una limpieza diferida, no un borrado en el mismo request:

- Un proceso que recorra `media_asset` con `deleted_at` más viejo que N días y
  borre su objeto del bucket.
- **N tiene que ser mayor que la ventana de sincronización más larga que se
  quiera soportar**: mientras un teléfono pueda estar sin señal con esa foto en
  su galería, el archivo sigue haciendo falta.
- Marcar la fila como purgada, para no volver a intentarlo y para que se note
  que el binario ya no existe.

Borrarlo en el mismo `DELETE` es lo que **no** hay que hacer: un borrado suave
que destruye el archivo no es suave, es duro con la fila de recuerdo.

## Workaround actual

Ninguno hace falta. El objeto queda y no molesta a nadie más que a la factura.

## Trigger

- Cuando el almacenamiento en B2 pase de lo que cueste mirar en la factura.
- O **antes de la primera empresa que no sea la de William**: con más de un
  cliente, lo que borra uno lo paga la plataforma.
