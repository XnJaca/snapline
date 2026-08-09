---
id: SPEC-0006
title: "Portal del Cliente"
aliases:
  - "SPEC-0006: Portal del Cliente"
type: spec
platform: web
status: implementado
goal: "El dueño de la casa abre un link sin instalar nada y ve en qué etapa va su obra, sin ver nada que la empresa no haya aprobado."
apps: [api]
depends_on: []
domain: [acceso-del-cliente, proyecto, oferta-y-lead]
frente: cliente
created: 2026-08-08
updated: 2026-08-08
tags:
  - spec
  - spec/implementado
---

# SPEC-0006: Portal del Cliente

> **Spec retroactivo.** Se escribió después de implementar, contra la regla 2.

## Problema

El cliente que ya pagó una obra es el lead más barato que existe. Pero un dueño de
casa no instala una app por un trabajo de dos semanas.

**Contradicción conocida:** este frente está *refutado* por la evidencia — William
dijo que no mandan fotos y que el cliente solo ve el resultado final. Entró por
decisión de producto. Ver [[../../product/vision#Contradicción abierta — el portal del cliente]].

## Alcance

### Entra
- Magic link con token hasheado y vencimiento
- Dos modos por proyecto: **Etapas** (default) y Avance
- Actualizaciones publicadas explícitamente, con fotos en nivel `CLIENT`
- Ofertas de otros servicios, y el lead que generan
- Revocar el acceso

### No entra
- Cuenta reclamable: el ADR la contempla, no está implementada
- Chat: no hay mensajería bidireccional
- El cliente no sube nada
- Nunca ve costos, horas ni datos internos

## Contrato de API

```http
POST   /api/client-access          → devuelve el link, token en claro una sola vez
DELETE /api/client-access/:id      → revoca
POST   /api/client-access/updates/:projectId
GET    /api/p/:token               ← anónimo
POST   /api/p/:token/offers        ← anónimo
```

## Criterios de aceptación

- [x] El token se guarda **hasheado**: una fuga de base no entrega accesos usables
- [x] Expira, se revoca, y ambos casos devuelven `TOKEN_INVALID`
- [x] En modo **Etapas** no salen updates ni fotos, aunque existan aprobados
- [x] Rate limit de 8/min: sin eso, adivinar un token es cuestión de tiempo de CPU
- [x] Nada llega al cliente sin `published_at`

## Riesgos / consideraciones

El endpoint es anónimo y el token identifica la empresa, así que no hay contexto de
tenant al resolverlo. Va por `client_access_by_token()`, `SECURITY DEFINER`.

Al implementarlo apareció que **`runUnscoped()` no bypassaba RLS** — solo logueaba.
Se renombró a `runWithoutTenant()` y su doc ahora dice que no es un bypass.

**Default en Etapas a propósito:** una foto de media obra genera más preguntas que
confianza, y así el frente se sostiene aunque William nunca active el avance.

## ADRs relacionados

- [[../../adr/0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | implementado | Spec retroactivo sobre código ya en `main` |
