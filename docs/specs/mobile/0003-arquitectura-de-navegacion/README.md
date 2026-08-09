---
id: SPEC-0003
title: "Arquitectura de navegación: el proyecto como contenedor"
aliases:
  - "SPEC-0003: Arquitectura de navegación: el proyecto como contenedor"
type: spec
platform: mobile
status: borrador
goal: "Cada rol entra a la superficie que le corresponde, y toda la información de una obra —avance, fotos y horas— se lee dentro de esa obra y no en listas globales."
apps:
  - mobile
depends_on:
  - "0001-login-movil"
domain:
  - usuario-y-membresia
  - proyecto
frente: plataforma
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/borrador
  - mobile
---

# SPEC-0003: Arquitectura de navegación: el proyecto como contenedor

> **Meta**
> - Apps afectadas: `mobile`
> - Depende de: [[../0001-login-movil/README|SPEC-0001]]
> - Frente: `plataforma`

---

## Problema

Después del login la app no tiene a dónde ir, y el esqueleto que se elija ahora
decide dónde va a colgarse todo lo que viene.

La trampa fácil es una barra con Fotos y Horas como pestañas globales. Se ve
ordenado y contradice la visión: *"todo arranca en un proyecto: información del
cliente → descripción → carpeta de fotos y documentos"*. Con listas globales el
proyecto deja de ser el contenedor y pasa a ser una etiqueta, y la pregunta que
William hizo textualmente —*"no sé cuántos mandé a cada proyecto"*— se queda sin
lugar donde contestarse.

El segundo problema es que la estructura no puede ser la misma para todos. El
trabajador no administra una cartera de obras; el dominio le da *"marcar entrada y
salida, tomar fotos. Nada más"*.

## Alcance

### Entra

- Barra inferior con los ejes que corresponden al rol.
- **El proyecto como contenedor**: al entrar a una obra, tabs superiores con la
  información **de esa obra**.
- Pantallas placeholder para cada destino; el contenido llega con su propio spec.
- La app recuerda la última pestaña y vuelve a ella al reabrir.
- Cada pestaña conserva su estado al cambiar entre ellas.

### No entra

- **El contenido del timeline de Avance.** Qué eventos entran, cómo se ordenan y
  de dónde salen es un spec propio. Acá solo se define que la tab existe.
- **El contenido de las demás pantallas.** Cada una necesita su spec.
- **La tab de Publicar** en un proyecto terminado. Es el frente `publicidad`; el
  lugar donde va a colgarse ya queda definido, pero no se construye ahora.
- **Filtrar proyectos por cuadrilla.** El `FOREMAN` no navega cartera en esta
  versión, así que no hace falta.
- Cambiar de empresa desde la navegación. Es DEBT-0002.

## Modelo de dominio afectado

- [[../../../domain/proyecto|proyecto]] — pasa a ser el contenedor de la navegación,
  como ya lo es del modelo.
- [[../../../domain/usuario-y-membresia|usuario-y-membresia]] — de sus roles sale
  qué superficie ve cada uno.

No se agrega nada al modelo.

## La estructura

### Barra inferior, por rol

| Rol | Ejes |
|---|---|
| `OWNER`, `ADMIN` | Proyectos · Clientes · Reportes · Facturación |
| `FOREMAN` | Hoy · Cuadrilla · Fotos |
| `WORKER` | Hoy · Fotos |
| `ACCOUNTANT` | Reportes · Facturación |

Por qué cada una, con su fundamento y no por gusto:

- **El dueño ve ejes de negocio, no de jornada.** No ficha entrada, así que "Hoy"
  no le sirve; lo que necesita es el estado general. Fotos y Horas desaparecen de
  su barra porque viven **dentro** de cada obra, que es donde significan algo.
- **El `WORKER` no tiene lista de proyectos.** Su día es una obra. Dos pestañas es
  el mínimo y es exactamente lo que promete la visión: *"la única pantalla que un
  trabajador debería necesitar"*.
- **El `FOREMAN` es el trabajador más su gente.** El dominio le da *"ver su
  proyecto"*, en singular: no navega cartera, pero sí tiene `crews.read`.
- **El `ACCOUNTANT` no ve Fotos.** El dominio dice *"cero acceso a fotos"* y
  `media.read` no lo incluye.

### Dentro de un proyecto

```
┌──────────────────────────────────────┐
│  ← Kitchen remodel        · activo   │
│  ┌──────┬───────┬───────┬─────────┐  │
│  │Avance│ Fotos │ Horas │ Detalle │  │
│  └──────┴───────┴───────┴─────────┘  │
│                                      │
│   ● Carlos marcó entrada    7:12     │
│   ● 3 fotos · fachada       9:40     │
│   ● Carlos marcó salida    15:40     │
│   ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈  │
│   ● cambió a En proceso              │
│                                      │
└──────────────────────────────────────┘
```

**Avance es un timeline lineal de la obra hasta su cierre.** Es la respuesta a
"cuántos mandé y qué se hizo", y es además la fuente natural de dos cosas que la
visión ya pide: lo que ve el cliente en su portal —*"actualizaciones y fotos que
William marcó como visibles"*— y el material que se publica al cerrar.

Las mismas cuatro tabs en un proyecto terminado. El timeline no cambia de forma:
simplemente termina.

### Los permisos filtran, no eligen

Qué ejes ve cada rol es decisión de producto y vive en el móvil. Lo que **no** vive
acá es la tabla de quién puede qué: cada destino declara el permiso que necesita y
se oculta si no está en `membership.permissions`, que devuelve el login.

Así, un permiso que cambia en el servidor no deja una pestaña que lleve a un `403`,
y el móvil nunca decide por su cuenta qué puede hacer un rol.

## Comportamiento sin señal

La navegación es **enteramente local**: el rol y los permisos vienen de la sesión
guardada, que ya está en el dispositivo desde el login.

| Situación | Comportamiento |
|---|---|
| Sin red, con sesión | La estructura se arma igual, desde la sesión guardada. |
| Sin red, token vencido | Igual: los permisos no se revalidan para dibujar la interfaz. |
| Sin red, dentro de un proyecto | Las tabs existen; cada una muestra lo que tenga en local. |

**Los permisos cacheados son conveniencia de interfaz, nunca autoridad**, tal como
dice la ficha de dominio. Que una pestaña se dibuje no significa que su acción vaya
a pasar: el guard del API verifica cada request al sincronizar.

## UI

- **Icono y texto siempre** en la barra inferior, nunca solo icono: un icono sin
  etiqueta obliga a aprender qué significa, y la promesa es que no haga falta
  entrenamiento.
- Alto mínimo **64dp**, igual que la acción primaria y por la misma razón.
- La pestaña activa usa el color de marca; las demás, el atenuado. Como el texto
  acompaña al icono, el estado no depende solo del color.
- Las tabs de proyecto son superiores y desplazables si no entran, nunca apiladas
  en dos filas.
- Nunca menos de dos ejes ni más de cuatro. Si un rol quedara con uno, no se
  muestra barra.

## Criterios de aceptación

- [ ] Un `OWNER` ve cuatro ejes: Proyectos, Clientes, Reportes y Facturación.
- [ ] Un `OWNER` **no** tiene pestañas globales de Fotos ni de Horas: solo se llega
      a ellas entrando a un proyecto.
- [ ] Un `WORKER` ve exactamente dos: Hoy y Fotos, y **no** ve lista de proyectos.
- [ ] Un `FOREMAN` ve tres, incluida Cuadrilla.
- [ ] Un `ACCOUNTANT` **no** ve la pestaña de Fotos.
- [ ] Entrar a un proyecto muestra cuatro tabs: Avance, Fotos, Horas y Detalle.
- [ ] Un proyecto terminado muestra las mismas cuatro tabs.
- [ ] Un destino cuyo permiso falta en `membership.permissions` no se dibuja: una
      sesión con permisos recortados a mano muestra menos entradas.
- [ ] Ningún rol ve menos de dos ni más de cuatro ejes.
- [ ] Cambiar de pestaña y volver conserva la posición de scroll de la anterior.
- [ ] Cerrar la app y reabrirla vuelve a la última pestaña usada.
- [ ] La estructura se arma sin red, desde la sesión guardada.
- [ ] La barra se ve correcta en claro y en oscuro, y pasa AA en los dos.
- [ ] Ningún título está quemado: todos pasan por i18n en `en` y `es`.

## Riesgos / consideraciones

**"Hoy" significaba dos cosas.** Para el trabajador es su jornada; dentro de un
proyecto era la historia de la obra. Se resolvió llamando **Avance** a la tab del
proyecto y dejando **Hoy** para la jornada. Si vuelve a aparecer un nombre que sirve
en dos niveles, conviene revisarlo antes de construirlo.

**Todo son placeholders.** Es andamiaje deliberado: se construye la estructura para
que cada spec de pantalla llegue a un lugar ya definido. El riesgo es que queden
vacíos mucho tiempo y la app se sienta hueca al demostrarla — conviene que la
siguiente feature llene Avance, que es la que cuenta la historia.

**El `FOREMAN` sin cartera puede quedarse corto.** Si resulta que necesita ver más
de una obra a la vez, la salida es darle la lista filtrada por su cuadrilla, lo que
requiere filtrar proyectos por cuadrilla en el API. Se sabrá al usarlo.

## ADRs relacionados

- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]] — go_router
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — el color de
  marca en la pestaña activa, y los 64dp

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | borrador | Creado como "navegación por rol" |
| 2026-08-08 | borrador | Reescrito: el proyecto pasa a ser el contenedor y Fotos/Horas dejan de ser ejes globales. Revisado con `spec-reviewer`, que detectó que `WORKER` no tiene `time.read`; la tabla de roles duplicada se eliminó llevando los permisos al contrato. |
