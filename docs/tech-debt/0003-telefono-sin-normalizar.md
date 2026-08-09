---
id: DEBT-0003
title: "El teléfono se compara sin normalizar al iniciar sesión"
aliases:
  - "DEBT-0003: El teléfono se compara sin normalizar al iniciar sesión"
type: tech-debt
status: resuelta
severity: media
origin: "SPEC-0001"
apps:
  - api
trigger: "El primer reporte de un trabajador que no puede entrar con un teléfono correcto"
created: 2026-08-08
updated: 2026-08-08
tags:
  - tech-debt
  - tech-debt/resuelta
  - auth
---

# DEBT-0003: El teléfono se compara sin normalizar al iniciar sesión

## Contexto

Detectado al escribir [[../specs/mobile/0001-login-movil/README|SPEC-0001]].

[[../domain/usuario-y-membresia|usuario-y-membresia]] deja `email` opcional porque
**muchos trabajadores no usan correo**: para buena parte de la cuadrilla el teléfono
va a ser la única forma de entrar.

## Qué no se hizo

`apps/api/src/auth/auth.service.ts` compara el identificador como texto plano:

```ts
.where('(u.email = :id OR u.phone = :id)', { id: identifier })
```

Un teléfono no tiene una sola forma escrita. Estos cuatro son el mismo número para
una persona y cuatro strings distintos para Postgres:

```
301-555-0142
(301) 555-0142
3015550142
+13015550142
```

La comparación es exacta, así que entrar depende de escribirlo igual que como quedó
guardado el día del alta. Tampoco hay normalización al **crear** el usuario, así que
el formato almacenado es el que haya tecleado quien lo dio de alta.

## Workaround actual

Ninguno automático. El admin le dice al trabajador exactamente cómo está cargado su
número, o edita el usuario para dejarlo en el formato que la persona escribe.

Es vivible mientras haya un solo contratista con pocos empleados dados de alta por
la misma persona.

## Costo de resolverla

Bajo. Normalizar a E.164 (`+13015550142`) en dos puntos de `apps/api`:

1. Al guardar, en la creación y edición de usuario.
2. Al consultar, normalizando el `identifier` antes del `where`.

Más una migración que normalice las filas existentes. Conviene hacerlo **antes** de
que haya volumen de usuarios: migrar diez teléfonos es trivial, migrar mil con
formatos heterogéneos no.

Maryland es todo `+1`, así que ni siquiera hace falta una librería completa de
parseo todavía.

## Costo de NO resolverla

El síntoma es un trabajador que no puede entrar y jura que su número está bien —
y tiene razón. El mensaje que ve es "credenciales inválidas", que apunta a la
contraseña, así que el diagnóstico real puede tardar bastante.

Es fricción concentrada justo en el primer día de uso de cada empleado nuevo, que
es cuando se decide si la app se adopta o se abandona. Y contradice la promesa de
que se usa sin entrenamiento.

## Trigger

**El primer reporte de "no puedo entrar" con un teléfono correcto.**

Trigger secundario: dar de alta trabajadores en volumen, o el segundo contratista
—ahí los formatos ya no los teclea una sola persona.

## Propuesta de solución

Normalizar a E.164 en el borde de `apps/api`: al escribir y al leer. El cliente
manda el texto tal cual lo escribió el usuario y el servidor se encarga, que es
coherente con la regla de que el servidor no confía en lo que deriva el cliente.

El móvil no participa: no debe adivinar si lo tecleado es un teléfono o un correo.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | backlog | Registrada al revisar el SPEC-0001 |

## Resolución — 2026-08-08

`src/auth/phone.ts` normaliza a E.164 antes de comparar, y el email a minúsculas.
Verificado contra el API: `+15551234567`, `15551234567`, `5551234567`,
`555-123-4567`, `(555) 123 4567` y ` 555.123.4567 ` entran todas al mismo usuario.
Cubierto por `src/auth/phone.spec.ts`.

**Lo que quedó a medias, a propósito:** solo se normaliza **al leer**. Los números ya
guardados no se migraron, y el alta todavía no normaliza al escribir. Con el único
teléfono del seed no molesta, pero **antes de cargar trabajadores de verdad** hace
falta: normalizar en el registro, y una migración que arregle lo existente.

Asume país por defecto **US**, que es donde opera el design partner. El día que haya
usuarios fuera, el país sale de la empresa y el prefijo pasa a ser obligatorio.
