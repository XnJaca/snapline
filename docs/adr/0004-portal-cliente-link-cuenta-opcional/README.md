---
id: ADR-0004
title: "Portal del cliente por link, con cuenta opcional"
aliases:
  - "ADR-0004: Portal del cliente por link, con cuenta opcional"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
---

# ADR-0004: Portal del cliente por link, con cuenta opcional

## Contexto

El cliente final —el dueño de la casa— tiene que poder ver cómo va su proyecto, y
ahí mismo recibir ofertas de otros servicios de la empresa. El cliente que ya pagó
una obra es el lead más barato que existe.

El problema es la fricción: un dueño de casa no instala una app por un trabajo de
dos semanas.

Hay que registrar además una contradicción conocida: el brief documenta que este
frente fue **refutado con evidencia directa** — William dijo que no mandan fotos y
que el cliente solo ve el resultado final. Ver [[../../product/vision#Contradicción abierta — el portal del cliente|vision]].

## Decisión

El cliente entra por **magic link** enviado por SMS o email, sin instalar nada ni
crear cuenta. Puede **reclamar una cuenta** si quiere historial y notificaciones.

La visibilidad la decide William por proyecto, y el default es **Etapas**
(Inicio · En proceso · Finalizado), no Avance.

## Alternativas consideradas

### Alternativa A — Login con rol cliente en la app

El cliente usa la misma app con permisos recortados.

**Por qué no:** pedirle instalar y crear cuenta mata la mayoría de los accesos.
Habilita push, que es real, pero no compensa la fricción de entrada.

### Alternativa B — Solo link, sin posibilidad de cuenta

Más simple de construir y de asegurar.

**Por qué no:** cierra la puerta al cliente recurrente, que es justamente el que
más valor tiene para la venta cruzada.

## Consecuencias

### Positivas

- Fricción casi nula: el cliente abre un link y ve su obra.
- El canal de venta cruzada queda abierto sin pedir nada a cambio.
- El default en Etapas hace que el frente se sostenga aunque William nunca active
  la vista detallada — lo cual, según la evidencia, es lo probable.

### Negativas / Costos

- Dos caminos de autenticación que mantener y asegurar.
- Un link es un credencial que viaja por SMS: hay que tratarlo como tal.

### Riesgos

- **El token es la única barrera.** Mitigación: se guarda hasheado, expira, se acota
  a un proyecto, y el endpoint que lo consume lleva rate limit. Si viaja en la URL
  se filtra por `Referer`, así que no va en query string visible.
- **Escalada de visibilidad.** Un portador de token no puede pedir contenido
  `INTERNAL`. La regla vive en la base de datos, no en el formulario.
- **Se construye contra la evidencia disponible.** Mitigación: el default apagado,
  y no se invierte en este frente antes que en los que sí tienen dolor confirmado.

## Impacto en el modelo

- [[../../domain/acceso-del-cliente|acceso-del-cliente]]
- [[../../domain/oferta-y-lead|oferta-y-lead]]
- [[../../domain/contenido|contenido]]

## Referencias

- Reunión con William del 2026-08-08.
- Evidencia en contra: `product/brief.md`, sección "Refutado".
