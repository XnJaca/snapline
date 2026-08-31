---
id: DEBT-0010
title: "Una jornada en conflicto no tiene camino de resolución en el móvil"
aliases:
  - "DEBT-0010: Una jornada en conflicto no tiene camino de resolución en el móvil"
type: tech-debt
status: abierta
severity: media
origin: "SPEC-0011"
apps:
  - mobile
trigger: "El primer conflicto de horas visto en un teléfono real, o el spec que traiga aprobar en lote — el que llegue antes"
created: 2026-08-31
updated: 2026-08-31
tags:
  - tech-debt
  - campo
---

# DEBT-0010: Una jornada en conflicto no tiene camino de resolución en el móvil

## Contexto

`SyncStatus.conflict` existe desde SPEC-0004 y solo lo produce `time_entry`: la
regla 12 no deja que unas horas se sobrescriban solas, así que la fila se marca y
la mira un humano. `TimeEntryRepository.watchConflicts()` está escrito desde
entonces para alimentar esa pantalla.

**Esa pantalla nunca se hizo.** Ningún widget de `lib/features/` consume
`watchConflicts()`. SPEC-0011 sumó un tercer código que marca conflicto
—`TIME_ENTRY_DECISION_CONFLICTS`, cuando dos personas deciden distinto sobre las
mismas horas— y con eso el estado pasó de teórico a alcanzable en el uso normal:
alcanza con que William apruebe desde la web mientras un ADMIN rechaza desde el
teléfono.

La tab Horas **muestra** el conflicto en la fila, con su texto, así que no es
invisible. Lo que no hay es qué hacer después.

## Por qué se posterga

Es alcance que SPEC-0011 no declara, y meterlo habría sido implementar de más. La
pantalla de conflictos no es una vista de la obra: es transversal a toda la app
—cualquier jornada de cualquier obra puede quedar ahí— y merece decidir dónde
vive, quién la ve y qué acciones ofrece.

Se levantó a conciencia **después** de cerrar el hallazgo que sí era de esta
feature: mientras una decisión del propio dispositivo podía terminar en conflicto
sola, diferir esto era dejar sin salida un bug propio. Con el turno de la bandeja
cerrando esa ventana, llegar a un conflicto exige que decida otra persona — que
es el caso que la regla 12 quiere que mire un humano, y para el que la oficina
tiene la web.

## Workaround actual

La fila se ve marcada en la tab Horas de la obra, con el texto de que alguien más
decidió. La resolución se hace desde la web, o desde otro dispositivo cuyo estado
coincida con el del servidor.

## Qué haría falta

Una pantalla —probablemente colgada de la cuenta, no de una obra— que liste las
jornadas en conflicto de la empresa y ofrezca decidir de nuevo con el estado del
servidor a la vista. La decisión nueva ya tiene el mecanismo: sale con el
`expectedStatus` correcto porque `decidedFrom` se recalcula al encolar.

Lo que hay que definir es de producto, no técnico: si un `ADMIN` puede resolver un
conflicto que él mismo produjo, y si la pantalla muestra las dos versiones o solo
la del servidor.

## Lo otro que comparte causa: el pull no toma el turno

`push()` y `decide()` comparten el turno de la bandeja desde SPEC-0011, pero
`pull()` no. Dentro de una misma corrida de `sync()` da igual —van uno después
del otro—, pero un `decide()` disparado mientras un `pull()` de otra corrida está
en vuelo no tiene nada que lo detenga: el guard de `_aplicar()` excluye las filas
en `conflict`, no las que tienen una escritura local sin confirmar.

**No se pierde ninguna decisión.** El `expectedStatus` ya quedó fijo en el payload
encolado, así que el servidor la resuelve bien igual. Lo que puede pasar es que la
fila muestre `synced` un momento antes de tiempo, y se corrija en la
sincronización siguiente.

Se anota acá porque comparte la causa de fondo —nada distingue una fila con
escritura local sin confirmar, salvo el flag de conflicto— aunque el arreglo sea
otro: que `pull()` también tome el turno, o que su guard mire `pending` además de
`conflict`.

## Trigger

El primer conflicto de horas visto en un teléfono real, o el spec que traiga
aprobar en lote — que multiplica por N las chances de chocar con la web. El que
llegue antes.
