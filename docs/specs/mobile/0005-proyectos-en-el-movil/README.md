---
id: SPEC-0005
title: "Proyectos en el móvil"
aliases:
  - "SPEC-0005: Proyectos en el móvil"
type: spec
platform: mobile
status: en-implementacion
goal: "William ve las obras en proceso, abre cualquiera sin señal, y da de alta o corrige una —con su cliente y su propiedad si hacen falta— parado en la obra sin esperar cobertura."
apps:
  - mobile
  - api
depends_on:
  - "0003-arquitectura-de-navegacion"
  - "0004-capa-local-y-sincronizacion"
  - "0006-clientes-en-el-movil"
domain:
  - proyecto
  - cliente
frente: administrativo
created: 2026-08-09
updated: 2026-08-10
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0005: Proyectos en el móvil

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0003-arquitectura-de-navegacion/README|SPEC-0003]],
>   [[../0004-capa-local-y-sincronizacion/README|SPEC-0004]],
>   [[../0006-clientes-en-el-movil/README|SPEC-0006]]
> - Frente: `administrativo`

---

## Problema

El SPEC-0003 dejó el eje de Proyectos con andamiaje: cards sobre datos
sintéticos. Sirve para demostrar la estructura y no sirve para trabajar.

El proyecto es *"la unidad central del sistema: todo cuelga de acá"*, así que
esta pantalla es la puerta a todo lo demás. Y William **no tiene oficina**: si
para dar de alta una obra tiene que volver a una laptop, el móvil no le cierra el
ciclo y vuelve al cuaderno.

## Alcance

### Entra

- **Lista de obras en proceso** —solo `IN_PROGRESS`— leída de local.
- **Ver todas**, con filtro por los siete estados del dominio.
- **Detalle**: la tab `Detalle` del contenedor que SPEC-0003 dejó vacía.
- **Alta de obra** desde el teléfono, con UUIDv7 local.
- **Edición** de los campos que el dominio marca editables.
- **Cambio de estado**, ofreciendo **solo las transiciones válidas** desde el
  estado actual. La escalera del dominio se respeta en el selector, no como
  advertencia.
- **La validación de la escalera en `apps/api`**, que hoy no existe:
  `projects.service.ts` hace `update({ id }, dto)` sin comparar contra el estado
  anterior, así que acepta cualquier salto. Sin esto, el criterio del descarte
  retrocedente no se puede cumplir — el dispositivo no puede saber si su estado es
  viejo. Va en el mismo commit que el móvil (regla 26).
- Buscar por nombre de obra o por cliente.
- **Crear cliente y propiedad sin salir del alta**, en línea. Ver abajo.

### No entra

- **El timeline de Avance.** Qué eventos entran y cómo se ordenan es su spec.
- **Fotos y Horas de la obra.** Cada una con el suyo.
- **La ficha completa de cliente.** El alta en línea pide lo mínimo; el resto se
  llena desde [[../0006-clientes-en-el-movil/README|SPEC-0006]], que es dueño de
  esa pantalla.
- **Publicar.** Es el frente `publicidad`.
- **Asignar cuadrilla.** Vive en el frente `campo`.

## Modelo de dominio afectado

- [[../../../domain/proyecto|proyecto]] — se implementa su ficha tal cual está.
- [[../../../domain/cliente|cliente]] — se lee para elegir cliente y sitio, y se
  escribe en el alta en línea, con las mismas reglas que SPEC-0006.

No se agrega nada al modelo.

## Las reglas del dominio que aplican

- **El `site_id` tiene que pertenecer al `customer_id`.** El selector de sitio se
  llena **después** de elegir cliente y solo con los de ese cliente. No se
  cruzan.
- **`client_visibility_mode` arranca en `etapas`.** Pasar a `avance` es acción
  explícita, no un default de formulario.
- **`CANCELLED` no borra nada.** Cancelar una obra no la saca de la base ni toca
  sus horas: solo cambia el estado y deja de listarse en la principal.
- **La transición de estado retrocedente que llega tarde se descarta.** Lo dice
  la ficha, y es lo único de `project` que no es última escritura gana.
- **Un `WORKER` solo ve proyectos donde tiene asignación vigente.** No aplica a
  esta pantalla —el `WORKER` no tiene cartera (SPEC-0003)— pero sí a lo que la
  capa local guarde: el pull ya viene filtrado por el servidor y el móvil **no
  debe** asumir que tiene todo.

## Comportamiento sin señal

| Situación | Comportamiento |
|---|---|
| Abrir la lista | Sale de local. Idéntica con red y sin red. |
| Abrir el detalle | Igual: es lo que el goal promete, y no consulta nada. |
| Crear una obra | Se escribe local con UUIDv7 y entra a la bandeja. Aparece en la lista al instante, marcada como pendiente. |
| Editar | Igual: se aplica local y se encola. |
| Cambiar de estado | Igual. Si al sincronizar el servidor ya avanzó más, la transición retrocedente se descarta. |
| Elegir cliente o sitio | Solo se ofrecen los que están en local. Si el cliente es nuevo y no sincronizó, igual está — se creó en este dispositivo. |

**Lo pendiente se ve.** Una obra que todavía no llegó al servidor se muestra con
su marca, y no como si ya estuviera guardada. Se usa `StatusChip`, no un color
suelto.

## UI

Sobre lo que SPEC-0003 dejó armado:

- La cartera ya está: cards con estado, nombre, cliente, dirección, cuadrilla y
  fotos. Cambia la fuente de datos, no la forma.
- **La acción primaria es "＋ Nueva obra"**, y es lo único naranja sólido de la
  pantalla. "Ver todas" se queda secundario.
- El alta es un formulario en pantalla completa, no un diálogo: son varios campos
  y se llena parado en una obra, con guantes.
- Los campos obligatorios del dominio son `customer_id`, `site_id`, `name` y
  `status`. Nada más se pide en el alta; el resto se completa editando.

### El alta no manda a otra pantalla

Los campos **Cliente** y **Propiedad** son buscadores con "＋ crear nuevo" en
línea: abren una hoja de dos o tres campos y vuelven con el registro ya elegido.

Es la decisión de producto de esta pantalla, y tiene una razón concreta: William
está parado en la obra **con el cliente al lado**, y ese es el único momento en
que tiene los datos. Mandarlo a tres pantallas distintas es exactamente cuando la
gente deja de cargar y vuelve al cuaderno.

El cliente creado así lleva `display_name` y un contacto; la propiedad, su
dirección. Nada más — pedir la ficha completa parado en un techo es el otro modo
de que no se cargue nada. Se completan después desde Clientes.

**El formulario es el mismo de SPEC-0006, en versión mínima.** No se copian los
campos: si se duplican, divergen.

## Criterios de aceptación

- [x] La lista sale de la base local: apagando la red, la pantalla muestra lo
      mismo.
- [x] Ninguna pantalla de este frente importa un cliente de `lib/api/`.
- [x] La lista principal muestra solo `IN_PROGRESS`: una obra agendada o en
      pausa **no** aparece ahí, y sí en "ver todas".
- [x] Crear una obra sin señal la deja visible al instante, marcada como
      pendiente, y llega al servidor al volver la red sin duplicarse.
- [x] El id de la obra creada en el móvil es el mismo con el que queda en el
      servidor.
- [x] El selector de sitio solo ofrece sitios del cliente elegido, y cambiar de
      cliente lo vacía.
- [x] Se puede crear cliente, propiedad y obra **sin salir del alta y sin
      señal**, y las tres llegan al servidor en ese orden.
- [x] Una obra nueva nace con `client_visibility_mode = etapas`.
- [x] El selector de estado ofrece solo las transiciones que la ficha permite
      desde el estado actual: desde `LEAD` no se puede saltar a `COMPLETED`.
- [x] Una transición retrocedente que llega tarde **la descarta el servidor**, no
      el dispositivo: el móvil no puede saber si su estado es viejo.
- [x] Cancelar una obra la saca de la principal y **no** borra sus horas ni sus
      fotos. *(Verificado que no borra la obra ni la marca `deletedAt`; que no
      toque horas ni fotos no se puede comprobar todavía porque ninguna de las dos
      existe — vuelve a mirarse en el spec de asistencia.)*
- [x] Editar sin señal aplica local y encola una sola operación por edición.
- [x] La pantalla se ve correcta en claro y en oscuro, y la única cosa naranja
      sólida es "nueva obra".
- [x] Cero cadenas quemadas: todo en `en` y `es`, incluidos los siete estados.

## Riesgos / consideraciones

**El alta en línea duplica superficie con SPEC-0006.** Dos lugares crean un
cliente, y si divergen, uno de los dos va a quedar mal. Se evita con un solo
formulario compartido —el de SPEC-0006 en versión mínima— y no copiando campos.

**Una obra en pausa desaparece de la principal.** Es consecuencia de mostrar solo
`IN_PROGRESS`, y una obra trabada suele ser justamente la que necesita atención.
Queda a un toque en "ver todas". Vale la pena mirar con William si prefiere que
`ON_HOLD` vuelva a la principal; es cambiar un predicado.

**El servidor hoy no valida la escalera de estados.** `projects.service.ts` hace
`update({ id }, dto)` sin comparar contra el estado anterior, así que acepta
cualquier salto. Este spec lo resuelve del lado del selector, que es lo que puede;
que el servidor la valide es trabajo de `apps/api` y conviene hacerlo con
`project.update`, no después.

## ADRs relacionados

- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — la regla del
  naranja, que decide qué es la acción primaria de esta pantalla

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-09 | borrador | Creado. El diseño de la cartera y del detalle ya existe como andamiaje de SPEC-0003; este spec lo formaliza y le pone datos reales. |
| 2026-08-09 | borrador | Dos decisiones de producto cerradas: la principal muestra solo `IN_PROGRESS` —no "todo lo no cerrado"—, y el alta crea cliente y propiedad en línea en vez de mandar a tres pantallas. |
| 2026-08-10 | review | Verificados los prerequisitos contra el código: SPEC-0006 quedó implementado y dejó los formularios mínimos que el alta en línea reutiliza —`CustomerFields(minimal:)` y `showSiteFormSheet`—, más `site.create` y `site.update` en la bandeja. |
| 2026-08-10 | aprobado | Aprobada la escalera de estados en `apps/api`: el criterio del descarte retrocedente exige que la valide el servidor, así que `apps` suma `api` y va en commit atómico con el móvil (regla 26). |
| 2026-08-10 | en-implementacion | Arranca la implementación. |
| 2026-08-10 | en-implementacion | Los catorce criterios en `[x]`. **El diagrama del dominio no alcanzaba para derivar la tabla de transiciones**: leído literal, de `ON_HOLD` no salía ninguna flecha —obra trabada para siempre— y solo se podía cancelar desde `IN_PROGRESS`, cuando el caso más común es el más temprano. La tabla completa quedó en la ficha de `proyecto` y en `apps/api`, con un test que verifica que la copia del móvil no divergió. Verificado contra el API que el retroceso que llega tarde se descarta **sin fallar**: si respondiera error, la operación se reintentaría para siempre. |
| 2026-08-09 | borrador | Revisado con `spec-reviewer`. Encontró que el alta en línea da por hecho un camino que no existe: agregar una propiedad a un cliente ya sincronizado no tiene operación de sync, lo que pasó a ser prerequisito de SPEC-0004. Sumados `depends_on: 0006` —el formulario compartido es de ese spec—, la escalera de transiciones movida de Riesgos a Alcance con su criterio, y el dueño del descarte retrocedente declarado: el servidor. |
