---
id: SPEC-0002
title: "Idioma de la app"
aliases:
  - "SPEC-0002: Idioma de la app"
type: spec
platform: mobile
status: borrador
goal: "El trabajador elige su idioma la primera vez que abre la app, lo ve aplicado antes de escribir sus credenciales, y puede cambiarlo después desde configuración sin reinstalar."
apps:
  - mobile
  - api
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
  - i18n
---

# SPEC-0002: Idioma de la app

> **Meta**
> - Apps afectadas: `mobile`, `api`
> - Depende de: [[../0001-login-movil/README|SPEC-0001]]
> - Frente: `campo`

---

## Problema

Hoy la pantalla de login sale en el idioma **del teléfono**, no en el de la persona.

Eso rompe justo donde más duele: un trabajador que recibió un teléfono usado, o
que lo compró configurado en inglés, ve la primera pantalla del producto en un
idioma que quizá no lee. Y el `locale` de su cuenta, que sí es el correcto, no se
conoce hasta **después** de iniciar sesión — o sea, después de haber leído esa
pantalla.

Es la contradicción más directa con *"se usa sin entrenamiento"*: la app pide
credenciales antes de hablarle en su idioma.

## Alcance

### Entra

- Pantalla de elección de idioma en el **primer arranque**, antes del login.
  Se muestra una sola vez.
- La elección se guarda en el dispositivo y sobrevive a cerrar la app.
- Cambiar el idioma desde **configuración**, en cualquier momento.
- Al cambiarlo con sesión abierta, se propaga a la cuenta con
  `PATCH /auth/me/locale`, para que el idioma siga a la persona a otro dispositivo.

### No entra

- **Más idiomas que `en` y `es`.** El enum del API los fija; agregar uno es cambio
  de contrato y de dominio.
- **Detectar el idioma por la región del teléfono.** El dispositivo ya expone su
  locale y no acierta más que preguntar.
- **Traducir contenido cargado por el usuario** —nombres de proyecto, notas—. Eso
  es dato, no interfaz.
- Idioma por empresa. El dominio lo pone en `user` a propósito.

## Modelo de dominio afectado

- [[../../../domain/usuario-y-membresia|usuario-y-membresia]] — `locale` ya existe
  como atributo de `user`, con valores `en` y `es`. **No se agrega nada al modelo.**

## Comportamiento sin señal

La elección de idioma es **enteramente local** y nunca depende de la red:

| Situación | Comportamiento |
|---|---|
| Primer arranque, sin red | Se elige igual. Es una preferencia del dispositivo. |
| Cambio en configuración, sin red | Se aplica al instante en la app. |
| Cambio sin red, con sesión abierta | La app queda en el idioma nuevo; **la cuenta se actualiza cuando vuelva la red**. |
| Sin red y el `PATCH` falla | No se muestra error al usuario: lo que eligió ya se aplicó. Se reintenta. |

**El idioma nunca se pierde por falta de red.** Lo que puede demorar es que la
cuenta se entere, y eso no afecta al usuario en ese dispositivo.

## Precedencia

Tres fuentes, en este orden:

```
1. lo que el usuario eligió en este dispositivo   ← manda
2. el `locale` de su cuenta (user.locale)
3. el idioma del sistema operativo
```

La elección explícita gana sobre la cuenta: si alguien tocó el selector, la app no
puede cambiárselo sola al iniciar sesión.

## Contrato de API

**Endpoint nuevo**, creado con este spec:

```http
PATCH /auth/me/locale
Authorization: Bearer <token>
{ "locale": "es" }
```

```json
{
  "id": "019fe2e4-...",
  "name": "Carlos Ramírez",
  "locale": "es",
  "email": null,
  "phone": "+15551234567"
}
```

- Permiso `profile.write`, que tienen **todos** los roles: cada persona cambia lo
  suyo.
- **El id sale del token**, nunca del cuerpo. No hay forma de cambiarle el idioma
  a otra persona.
- `locale` fuera de `en` / `es` responde `400` con el detalle del campo.
- Sin token responde `401`.

## UI

### Primer arranque

```
┌─────────────────────────┐
│                         │
│        ╲                │   marca, sin texto todavía:
│       Snapline          │   no se sabe qué idioma lee
│                         │
│  ┌───────────────────┐  │
│  │     Español       │  │   64dp cada uno
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │     English       │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Cada opción se escribe en su propio idioma**, nunca traducida: "Español" y
"English", no "Spanish"/"Inglés". Es lo único que se puede leer sin saber ya el
idioma de la app.

Sin texto explicativo arriba: cualquier frase estaría en un idioma que la mitad de
los usuarios no lee.

### Configuración

Entrada de lista con el idioma actual a la derecha. Al tocarla, las mismas dos
opciones.

## Criterios de aceptación

- [ ] En el primer arranque aparece la elección de idioma, antes del login.
- [ ] Cada opción está escrita en su propio idioma.
- [ ] Elegir español deja la pantalla de login en español, sin reiniciar.
- [ ] En el segundo arranque **no** vuelve a preguntar.
- [ ] La elección sobrevive a cerrar y reabrir la app.
- [ ] Con sesión abierta, cambiar el idioma en configuración lo persiste en la
      cuenta: al entrar en otro dispositivo, el idioma es el nuevo.
- [ ] Si el `PATCH` falla por falta de red, el idioma igual queda aplicado en la
      app y no se muestra ningún error.
- [ ] La elección del usuario gana sobre el `locale` de la cuenta al iniciar sesión.
- [ ] `PATCH /auth/me/locale` con un valor fuera del enum responde `400`.
- [ ] `PATCH /auth/me/locale` sin token responde `401`.
- [ ] Ningún texto de estas pantallas está quemado: todo pasa por i18n en `en` y `es`.

## Riesgos / consideraciones

**El reintento del `PATCH` sin red no tiene todavía dónde encolarse.** La bandeja
de salida es del ADR-0008 pero no existe: hasta que exista, el cambio de idioma sin
red se aplica local y se propaga en el próximo cambio o login. Es aceptable porque
el único efecto de la desincronización es de qué idioma salen las notificaciones
push, no cómo se ve la app.

**Las push se traducen con el `locale` de la cuenta**, según
`code-guidelines/i18n.md`. Mientras la cuenta no se entere de la elección local, un
trabajador podría ver la app en español y recibir la push en inglés. Es la razón
por la que este spec incluye el endpoint y no se conforma con guardar local.

## ADRs relacionados

- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]]
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | borrador | Creado. El endpoint `PATCH /auth/me/locale` ya está implementado y verificado en `apps/api`. |
