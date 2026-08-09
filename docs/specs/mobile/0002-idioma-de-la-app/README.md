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
frente: plataforma
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
> - Frente: `plataforma`

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
- Propagar el idioma a la cuenta con `PATCH /auth/me/locale`, **para que las
  notificaciones push salgan en el idioma correcto**. Ver "Precedencia": no es
  para sincronizar la interfaz entre dispositivos.
- Comparar el idioma local contra `user.locale` al iniciar sesión, y propagar si
  difieren. Es un cambio al flujo del [[../0001-login-movil/README|SPEC-0001]].

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
| Cambio sin red, con sesión abierta | La app queda en el idioma nuevo. El `PATCH` falla y **no se muestra ningún error**: lo que el usuario pidió ya pasó. |

**El idioma nunca se pierde por falta de red.** Lo que puede demorar es que la
cuenta se entere, y eso no afecta cómo se ve la app en este dispositivo.

### El reintento, sin bandeja de salida

La bandeja de salida del ADR-0008 **todavía no existe**, así que este spec no puede
apoyarse en ella. En vez de prometer un reintento automático que nadie dispara, el
mecanismo es explícito y acotado:

**Cada vez que se inicia sesión se compara el idioma local contra el `user.locale`
recibido, y si difieren se manda el `PATCH`.** Eso significa agregar esa comparación
al flujo de login del [[../0001-login-movil/README|SPEC-0001]], que ya está
implementado.

Consecuencia aceptada: si alguien cambia el idioma sin red y no vuelve a iniciar
sesión en semanas, sus push llegan en el idioma viejo durante ese tiempo. Es
vivible porque el efecto es sobre notificaciones, no sobre la app, y porque el
único caso que lo produce es cambiar de idioma justo sin cobertura.

Cuando exista la bandeja de salida, esto pasa a ser una mutación encolada más y la
comparación en el login deja de hacer falta.

## Precedencia

```
1. lo que el usuario eligió en este dispositivo   ← manda siempre
2. el idioma del sistema operativo                ← solo antes de elegir
```

La elección explícita gana, incluso sobre el `locale` de la cuenta: si alguien tocó
el selector, la app no puede cambiárselo sola al iniciar sesión.

### Qué significa eso para `user.locale`

Como el picker aparece **antes** del login, para cuando se conoce la cuenta ya hay
una elección local, y esa elección gana siempre. **En la práctica, `user.locale` no
decide cómo se ve la app en este dispositivo.**

Conviene decirlo claro en vez de dejarlo implícito, porque de ahí salen dos cosas:

- **El endpoint no existe para sincronizar la interfaz entre dispositivos.** Existe
  para que el servidor sepa en qué idioma hablarle a esa persona — y hoy eso son
  las **notificaciones push**, que se traducen con el `locale` de la cuenta según
  `code-guidelines/i18n.md`. Sin el `PATCH`, alguien podría tener la app en
  español y recibir las push en inglés.
- **En un teléfono nuevo el picker vuelve a preguntar**, porque es una preferencia
  del dispositivo y ahí todavía no hay ninguna. No se hereda de la cuenta, y está
  bien: preguntar una vez cuesta menos que adivinar mal.

### Cuándo se propaga a la cuenta

Dos momentos, los dos concretos:

1. **Al iniciar sesión**, si el idioma elegido en el dispositivo difiere del
   `user.locale` que devolvió el login.
2. **Al cambiarlo en configuración**, si hay sesión abierta.

## Contrato de API

Endpoint **ya implementado y verificado** en `apps/api`, junto con este spec:

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
      cuenta: `GET /auth/me` y el siguiente login devuelven el `locale` nuevo.
- [ ] Si el `PATCH` falla por falta de red, el idioma igual queda aplicado en la
      app y no se muestra ningún error.
- [ ] La elección del usuario gana sobre el `locale` de la cuenta al iniciar sesión,
      y además la corrige: tras entrar, la cuenta queda con el idioma elegido.
- [ ] Las claves del selector **no se traducen**: "Español" y "English" se leen
      igual con la app en cualquiera de los dos idiomas.
- [ ] `PATCH /auth/me/locale` con un valor fuera del enum responde `400`.
- [ ] `PATCH /auth/me/locale` sin token responde `401`.
- [ ] Ningún texto de estas pantallas está quemado: todo pasa por i18n en `en` y `es`.

## Riesgos / consideraciones

**Las claves del selector no se pueden traducir, y ya existían unas que sí lo
hacían.** `localeSpanish` / `localeEnglish` devolvían "Spanish"/"Español" según el
idioma activo — exactamente el bug que este spec evita. Se eliminaron y se
reemplazaron por `languageSpanish` / `languageEnglish`, idénticas en los dos ARB.
Si alguien agrega un idioma, su etiqueta se escribe en ese idioma en **todos** los
archivos.

**El picker vuelve a aparecer en cada instalación nueva.** Es consecuencia de que
sea preferencia del dispositivo, y de que se pregunte antes de conocer la cuenta.
Si alguna vez molesta, la salida no es leer `user.locale` antes del login —no se
puede— sino dejar de mostrar el picker cuando el idioma del sistema ya sea `en` o
`es`. No se hace ahora porque el caso que motiva el spec es justamente el teléfono
configurado en un idioma que la persona no lee.

## ADRs relacionados

- [[../../../adr/0008-arquitectura-flutter/README|ADR-0008]]
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]]

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | borrador | Creado. El endpoint `PATCH /auth/me/locale` ya está implementado y verificado en `apps/api`. |
