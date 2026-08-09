---
id: SPEC-0003
title: "Navegación por rol"
aliases:
  - "SPEC-0003: Navegación por rol"
type: spec
platform: mobile
status: borrador
goal: "Cada rol ve en la barra inferior solo las pestañas de lo que su rol puede hacer, y la app recuerda en cuál estaba al volver."
apps:
  - mobile
depends_on:
  - "0001-login-movil"
domain:
  - usuario-y-membresia
frente: campo
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/borrador
  - mobile
---

# SPEC-0003: Navegación por rol

> **Meta**
> - Apps afectadas: `mobile`
> - Depende de: [[../0001-login-movil/README|SPEC-0001]]
> - Frente: `campo`

---

## Problema

Después de iniciar sesión la app no tiene a dónde ir: hay una sola pantalla y
ningún esqueleto donde colgar las que vienen.

Pero el esqueleto no puede ser el mismo para todos. La visión es explícita en que
el trabajador necesita *"la única pantalla que un trabajador debería necesitar"*, y
[[../../../domain/usuario-y-membresia|el dominio]] define qué puede cada rol.
Mostrarle a un `WORKER` pestañas de clientes y facturación es exactamente lo que
hace que una app se sienta complicada — y es lo que perdemos contra QuickBooks.

Hay además un caso que no es de comodidad sino de regla: el `ACCOUNTANT` tiene
**cero acceso a fotos**, y eso está escrito en el dominio.

## Alcance

### Entra

- Barra de navegación inferior cuyas pestañas dependen del rol de la membresía
  activa.
- Cada pestaña es una pantalla **placeholder** con su título; el contenido llega
  con el spec de cada una.
- La app recuerda la última pestaña usada y vuelve a ella al reabrir.
- Cambiar de pestaña no recarga las otras: cada una conserva su estado.

### No entra

- **El contenido de las pantallas.** Cada una necesita su propio spec; acá solo se
  construye dónde van.
- **Cambiar de empresa desde la barra.** Es DEBT-0002 y necesita un endpoint que
  no existe.
- **Menú lateral, o navegación secundaria dentro de cada pestaña.**
- **Ocultar pestañas por permisos finos.** El rol decide; no hay configuración por
  usuario.

## Modelo de dominio afectado

- [[../../../domain/usuario-y-membresia|usuario-y-membresia]] — de su tabla de
  roles salen las pestañas. **No se agrega nada al modelo.**

## Las pestañas

Derivadas de lo que el dominio dice que puede cada rol, no inventadas:

| Rol | Pestañas |
|---|---|
| `WORKER` | Hoy · Fotos · Mis horas |
| `FOREMAN` | Hoy · Cuadrilla · Fotos · Horas |
| `OWNER`, `ADMIN` | Proyectos · Clientes · Fotos · Horas |
| `ACCOUNTANT` | Reportes · Facturación |

Tres cosas que no son arbitrarias:

- **`WORKER` no ve Proyectos ni Clientes.** Su día es una obra, no una cartera.
  El dominio le da "marcar entrada y salida, tomar fotos. Nada más".
- **`ACCOUNTANT` no ve Fotos.** El dominio dice *"cero acceso a fotos"*, y los
  permisos del API lo confirman: `media.read` no lo incluye. Una pestaña que
  llevara a un 403 sería una promesa rota.
- **`FOREMAN` ve Cuadrilla** porque el dominio le da "su cuadrilla: marcar por su
  gente", que ningún otro rol de campo tiene.

**Nunca menos de dos ni más de cuatro.** Con una, la barra sobra; con cinco, los
objetivos táctiles se vuelven demasiado angostos para un dedo con guante.

## Comportamiento sin señal

La navegación es **enteramente local**: el rol viene de la sesión guardada, que ya
está en el dispositivo desde el login.

| Situación | Comportamiento |
|---|---|
| Sin red, con sesión | Las pestañas se arman igual, desde la sesión guardada. |
| Sin red, token vencido | Igual: el rol no se revalida para dibujar la interfaz. |

**El rol cacheado es conveniencia de interfaz, nunca autoridad.** El servidor
verifica los permisos en cada request al sincronizar, tal como dice la ficha de
dominio. Que una pestaña se dibuje no significa que su acción vaya a pasar.

## UI

```
┌─────────────────────────┐
│  ╲ Snapline        [↪]  │   símbolo naranja, cerrar sesión
├─────────────────────────┤
│                         │
│      (contenido)        │
│                         │
├─────────────────────────┤
│   ◉        ○       ○    │
│  Hoy     Fotos   Horas  │   ≥64dp de alto
└─────────────────────────┘
```

- **Icono y texto siempre**, nunca solo icono: un icono sin etiqueta obliga a
  aprender qué significa, y la promesa es que no haga falta entrenamiento.
- Alto mínimo **64dp**, igual que la acción primaria y por la misma razón.
- La pestaña activa usa el color de marca; las demás, el color atenuado. Como el
  texto acompaña al icono, el estado no depende solo del color.

## Criterios de aceptación

- [ ] Un `WORKER` ve exactamente tres pestañas: Hoy, Fotos y Mis horas.
- [ ] Un `OWNER` ve cuatro: Proyectos, Clientes, Fotos y Horas.
- [ ] Un `ACCOUNTANT` **no** ve la pestaña de Fotos.
- [ ] Ningún rol ve menos de dos ni más de cuatro pestañas.
- [ ] Cambiar de pestaña conserva el estado de la anterior.
- [ ] Cerrar la app y reabrirla vuelve a la última pestaña usada.
- [ ] Cada pestaña muestra icono **y** texto.
- [ ] Las pestañas se arman sin red, desde la sesión guardada.
- [ ] Cerrar sesión y entrar con otro rol cambia las pestañas.
- [ ] La barra se ve correcta en claro y en oscuro, y pasa AA en los dos.
- [ ] Ningún título de pestaña está quemado: todos pasan por i18n en `en` y `es`.

## Riesgos / consideraciones

**La tabla de roles vive dos veces.** El API la tiene en
`apps/api/src/auth/permissions.ts` y el móvil necesita la suya para dibujar. Si un
rol gana un permiso en el servidor y acá no, la pestaña no aparece aunque debería —
falla silenciosa, del lado seguro.

Se acepta porque la alternativa —que el login devuelva la lista de permisos— es un
cambio de contrato que no vale para cuatro entradas. Si la tabla crece o empieza a
desincronizarse, se registra como deuda y se mueve al contrato.

**Las pestañas son placeholders.** Es andamiaje deliberado: se construye la
estructura para que cada spec de pantalla llegue a un lugar ya definido. El riesgo
es que queden placeholders mucho tiempo y la app se sienta vacía al demostrarla.

## ADRs relacionados

- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]] — go_router
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — el color de
  marca en la pestaña activa

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | borrador | Creado |
