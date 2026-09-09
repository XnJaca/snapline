---
id: DEBT-0015
title: "El banner dice «sin conexión» ante cualquier fallo del sincronizador"
aliases:
  - "DEBT-0015: El banner dice «sin conexión» ante cualquier fallo del sincronizador"
type: tech-debt
status: abierta
severity: media
origin: "SPEC-0011"
apps:
  - mobile
trigger: "El próximo fallo de sincronización que no sea de red — un 500 del servidor, un error de la base local — o la primera vez que alguien reporte «no tengo señal» teniendo señal"
created: 2026-09-07
updated: 2026-09-07
tags:
  - tech-debt
  - tech-debt/abierta
  - campo
---

# DEBT-0015: El banner dice «sin conexión» ante cualquier fallo del sincronizador

## Contexto

`syncControllerProvider` es un `bool`: el último intento salió bien o salió mal.
`OfflineBanner` lee ese booleano y, cuando es `false`, muestra:

> *"Sin conexión. Lo que hagas se guarda y se envía cuando vuelva la señal."*

**Que salga del intento y no del wifi es correcto y está bien razonado**: el
teléfono conectado al router de una obra sin internet dice que tiene conexión, y
creerle sería mentirle a quien está por cargar algo. El problema es el otro
extremo: **cualquier** fallo se cuenta como falta de red.

Se encontró probando SPEC-0011 en un teléfono real. Una migración local rota hacía
fallar el `pull` y el `push` en cada intento, y la app mostraba ese cartel. Las dos
mitades de la frase eran falsas: no era la señal, y lo que se cargara **no** iba a
enviarse después, porque la base no abría.

## Qué no se hizo

El bug de la migración se arregló (v10 pregunta por la columna antes de copiar).
El mensaje quedó como está: distinguirlo exige que el estado del sincronizador
deje de ser un booleano y diga **por qué** falló —red, servidor, o local—, y eso
toca el provider, el banner y las pantallas que lo observan.

## Workaround actual

Ninguno para quien usa la app. Para diagnosticar hay que mirar los logs: el
`Synchronizer` sí registra la excepción real con `[sync] pull falló` y su cadena.

## Costo de resolverla

Chico y acotado al móvil:

| Qué | Cambio |
|---|---|
| `sync_controller.dart` | El estado pasa de `bool` a un enum con `ok`, `sinRed`, `servidor`, `local` |
| `offline_banner.dart` | Un mensaje por caso; los que no son de red no prometen "cuando vuelva la señal" |
| `app_es.arb` / `app_en.arb` | Dos cadenas nuevas |

## Costo de NO resolverla

**El modo de fallo es silencioso y desvía el diagnóstico.** Quien ve "sin
conexión" busca señal, camina hasta la calle, espera. Nadie va a sospechar de la
base del teléfono ni de un 500 del servidor, y el problema real vive todo ese
tiempo sin que nadie lo reporte como lo que es.

Y hay un daño peor que el desvío: **la frase promete que lo cargado se enviará
solo**. Si el fallo es local, eso no va a pasar, y la promesa hace que nadie
vuelva a revisar.

## Trigger

El próximo fallo de sincronización que no sea de red, o la primera vez que
alguien reporte no tener señal teniéndola. Cualquiera de los dos es la señal de
que el cartel está desviando el diagnóstico y no solo siendo impreciso.
