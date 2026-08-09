---
id: SPEC-0005
title: "Proyectos en el móvil"
aliases:
  - "SPEC-0005: Proyectos en el móvil"
type: spec
platform: mobile
status: borrador
goal: "William ve sus obras vivas y abre cualquiera sin señal, y da de alta o corrige una parado en la obra sin esperar cobertura."
apps:
  - mobile
depends_on:
  - "0003-arquitectura-de-navegacion"
  - "0004-capa-local-y-sincronizacion"
domain:
  - proyecto
  - cliente
frente: administrativo
created: 2026-08-09
updated: 2026-08-09
tags:
  - spec
  - spec/borrador
  - mobile
---

# SPEC-0005: Proyectos en el móvil

> **Meta**
> - Apps afectadas: `mobile`
> - Depende de: [[../0003-arquitectura-de-navegacion/README|SPEC-0003]],
>   [[../0004-capa-local-y-sincronizacion/README|SPEC-0004]]
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

- **Lista de obras vivas** —ni `COMPLETED` ni `CANCELLED`— leída de local.
- **Ver todas**, con filtro por los siete estados del dominio.
- **Detalle**: la tab `Detalle` del contenedor que SPEC-0003 dejó vacía.
- **Alta de obra** desde el teléfono, con UUIDv7 local.
- **Edición** de los campos que el dominio marca editables.
- **Cambio de estado** por la escalera del dominio.
- Buscar por nombre de obra o por cliente.

### No entra

- **El timeline de Avance.** Qué eventos entran y cómo se ordenan es su spec.
- **Fotos y Horas de la obra.** Cada una con el suyo.
- **Crear el cliente desde el alta de obra.** Se elige uno existente; darlo de
  alta es [[../0006-clientes-en-el-movil/README|SPEC-0006]]. Si al construirlo
  resulta que el flujo se corta feo, se resuelve ahí y no acá.
- **Crear el `site`.** Un proyecto necesita `site_id`, así que en esta versión se
  elige entre los sitios existentes del cliente. Dar de alta una propiedad nueva
  entra en el spec de Clientes, que es de quien cuelga.
- **Publicar.** Es el frente `publicidad`.
- **Asignar cuadrilla.** Vive en el frente `campo`.

## Modelo de dominio afectado

- [[../../../domain/proyecto|proyecto]] — se implementa su ficha tal cual está.
- [[../../../domain/cliente|cliente]] — solo se lee, para elegir el cliente y su
  sitio.

No se agrega nada al modelo.

## Las reglas del dominio que aplican

- **El `site_id` tiene que pertenecer al `customer_id`.** El selector de sitio se
  llena **después** de elegir cliente y solo con los de ese cliente. No se
  cruzan.
- **`client_visibility_mode` arranca en `etapas`.** Pasar a `avance` es acción
  explícita, no un default de formulario.
- **`CANCELLED` no borra nada.** Cancelar una obra no la saca de la base ni toca
  sus horas: solo cambia el estado y deja de listarse en lo vivo.
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

## Criterios de aceptación

- [ ] La lista sale de la base local: apagando la red, la pantalla muestra lo
      mismo.
- [ ] Ninguna pantalla de este frente importa un cliente de `lib/api/`.
- [ ] La lista principal excluye `COMPLETED` y `CANCELLED`; "ver todas" las
      incluye y el filtro por estado las encuentra.
- [ ] Crear una obra sin señal la deja visible al instante, marcada como
      pendiente, y llega al servidor al volver la red sin duplicarse.
- [ ] El id de la obra creada en el móvil es el mismo con el que queda en el
      servidor.
- [ ] El selector de sitio solo ofrece sitios del cliente elegido, y cambiar de
      cliente lo vacía.
- [ ] Una obra nueva nace con `client_visibility_mode = etapas`.
- [ ] Cancelar una obra la saca de lo vivo y **no** borra sus horas ni sus fotos.
- [ ] Editar sin señal aplica local y encola una sola operación por edición.
- [ ] La pantalla se ve correcta en claro y en oscuro, y la única cosa naranja
      sólida es "nueva obra".
- [ ] Cero cadenas quemadas: todo en `en` y `es`, incluidos los siete estados.

## Riesgos / consideraciones

**Elegir cliente y sitio puede volverse el cuello de botella.** El alta depende
de que el cliente ya exista. Si al usarlo resulta que William casi siempre crea
la obra y el cliente juntos, hay que unir los dos flujos — se sabrá al probarlo
con él, y la salida está en el spec de Clientes.

**"Vivo" es una decisión de producto, no del dominio.** El dominio tiene siete
estados y ninguno se llama activo. Acá se define como *ni terminado ni
cancelado*. Si William dice que solo le importa lo que está en obra hoy, es
cambiar un predicado, pero conviene preguntárselo antes de la demo.

**El estado tiene una escalera y el formulario puede romperla.** La ficha define
transiciones; un selector que ofrezca los siete estados sueltos deja pasar saltos
que el dominio no contempla. Ofrecer solo las transiciones válidas desde el
estado actual.

## ADRs relacionados

- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — la regla del
  naranja, que decide qué es la acción primaria de esta pantalla

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-09 | borrador | Creado. El diseño de la cartera y del detalle ya existe como andamiaje de SPEC-0003; este spec lo formaliza y le pone datos reales. |
