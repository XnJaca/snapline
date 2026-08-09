---
id: CHANGELOG
title: "Changelog — bitácora humana"
type: changelog
tags:
  - changelog
---

# Changelog

Bitácora por **fecha**: qué se decidió y por qué. Para "qué se deployó en cada
versión", ver `RELEASES.md` cuando exista.

Se agrega con `/changelog <descripción>`.

---

## 2026-08-08 — sesión de móvil

- **`apps/mobile` existe.** Flutter con Riverpod 3, Drift, go_router, Dio y cliente
  generado desde `openapi.json`. Decidido en [[adr/0008-arquitectura-flutter/README|ADR-0008]],
  que también corrige el generador de ADR-0007: `swagger_parser` en vez de
  `openapi-generator`, porque el segundo exige una JVM que no está instalada.
- **Sistema de diseño cerrado** en [[adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]]:
  `design-tokens.json` en la raíz como fuente única, naranja de obra sobre neutros de
  gris puro, Inter para interfaz y Bricolage Grotesque **solo** para el wordmark.
  Los 34 pares de contraste pasan AA en los dos temas.
- **La regla del naranja.** El acento está a 17 grados del rojo de error y a 18 del
  ámbar de las banderas: el tono no alcanza para distinguirlos, así que lo hace la
  forma. Naranja sólido solo para la acción primaria; los estados siempre en chip
  tenue con icono obligatorio.
- **Login implementado y verificado** ([[specs/mobile/0001-login-movil/README|SPEC-0001]]):
  se entra con teléfono o correo indistintamente, la app toma el idioma del usuario, y
  reabrir no pide credenciales. 27 tests unitarios y 5 de integración contra el API real.
- **Un token vencido nunca borra la sesión.** Lo que se pierde sin sesión válida es
  sincronizar, no capturar — regla 9.
- **`frente: plataforma`** agregado a [[product/vision|vision]]. Los cinco frentes
  describen el producto; login, idioma, tema y navegación son cimiento y no se le
  facturan a nadie. Antes se declaraban `campo` por descarte.
- **`PATCH /auth/me/locale`** en `apps/api`, con permiso `profile.write` para todos
  los roles. Existe para que las notificaciones push salgan en el idioma correcto,
  que se traduce con el `locale` de la cuenta.
- **El login devuelve `membership.permissions`.** El móvil deja de replicar la tabla
  de roles: cada destino declara su permiso y el servidor dice cuáles tiene. Un
  permiso nuevo llega a un teléfono que no se actualizó.
- **Tres deudas registradas**, dos ya resueltas por la sesión del backend:
  [[tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001]] (tokens a Dart a mano),
  [[tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002]] y
  [[tech-debt/0003-telefono-sin-normalizar|DEBT-0003]].
- **Cuatro agentes de revisión** en `.claude/agents/`: `spec-reviewer`,
  `domain-guardian` y `contract-watcher` traídos de ACDEMIC y adaptados, más el
  `code-reviewer` que ya estaba. Encontraron dos bloqueantes reales en el SPEC-0001
  y uno en el SPEC-0003 que ningún humano habría visto leyendo el documento.

## 2026-08-08

- **Alcance reestructurado tras la reunión con William.** De "fotos que se publican"
  a plataforma de cinco frentes: administrativo, campo, cliente, reportes, publicidad.
  Publicar hacia afuera sigue siendo la premisa de venta; operaciones la alimenta.
  Ver [[product/vision|vision]] y [[product/roadmap|roadmap]].
- **Cuatro decisiones cerradas**: reemplazar QuickBooks, Flutter móvil + Angular admin,
  asistencia por geocerca con foto, portal de cliente por link con cuenta opcional.
- **Modelo de dominio definido antes de la primera migración.** Trece agregados con sus
  invariantes en [[domain/README|domain/]].
- **Sistema de documentación montado**: vault de Obsidian con specs, ADRs, dominio,
  deuda técnica y boards. Portado del que ya funciona en ACDEMIC.

## 2026-08-07

- Proyecto iniciado. Decisiones de arquitectura base y estado comercial en [[DECISIONES]].
- Nombre de trabajo `snapline`, pendiente de verificar. Ver [[NOMBRE]].
