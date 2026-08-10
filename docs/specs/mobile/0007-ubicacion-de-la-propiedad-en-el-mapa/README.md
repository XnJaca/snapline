---
id: SPEC-0007
title: "Ubicación de la propiedad en el mapa"
aliases:
  - "SPEC-0007: Ubicación de la propiedad en el mapa"
type: spec
platform: mobile
status: borrador
goal: "Una propiedad queda con su punto y su radio de geocerca fijados desde un mapa —tocándolo o usando la posición actual— y quien va a la obra ve dónde es antes de salir, sin que nadie escriba coordenadas a mano."
apps:
  - mobile
depends_on:
  - "0006-clientes-en-el-movil"
domain:
  - cliente
frente: campo
created: 2026-08-10
updated: 2026-08-10
tags:
  - spec
  - spec/borrador
  - mobile
---

# SPEC-0007: Ubicación de la propiedad en el mapa

> **Meta**
> - Apps afectadas: `mobile`
> - Depende de: [[../0006-clientes-en-el-movil/README|SPEC-0006]]
> - Frente: `campo`

---

## Problema

La propiedad tiene `lat`, `lng` y `geofence_radius_m` desde la primera migración, y
**hoy no hay forma de llenarlos**. [[../0006-clientes-en-el-movil/README|SPEC-0006]]
los dejó afuera a propósito: son de asistencia y entran con este frente.

Sin esos tres campos pasan dos cosas concretas:

- **La geocerca es teatro.** `evaluateGeofence` en `time-entries.service.ts` compara
  contra el punto del sitio; con el punto nulo, marcar entrada nunca puede evaluarse
  y la bandera de "fuera de la obra" no significa nada. Es la mitad de la promesa
  del frente de campo.
- **Nadie sabe a dónde ir.** Una dirección escrita alcanza para facturar y no para
  llegar: "9800 Georgia Ave" en un lote sin construir, o una casa cuyo acceso es por
  la calle de atrás, se resuelve mirando el punto en un mapa.

El caso que lo dispara: William manda una cuadrilla a una obra donde él ya estuvo y
ellos no. Hoy les manda la dirección por WhatsApp y contesta llamadas.

## Alcance

### Entra

- **Ver la propiedad en un mapa** desde su ficha, cuando tiene punto.
- **Fijar el punto**: tocando el mapa, o con un botón de "usar mi ubicación" para
  cuando William está parado en la obra.
- **Ajustar el radio de la geocerca**, con el círculo dibujado sobre el mapa: es la
  única forma de entender qué área cubre.
- **Abrir la dirección en la app de mapas del teléfono**, que es lo que resuelve
  "cómo llego" sin construir navegación.
- **Corregir el punto** de una propiedad que ya lo tenía.

### No entra

- **Ver personas en el mapa.** Ni en vivo ni histórico. Ver abajo.
- **Navegación dentro de la app.** Se delega a Google Maps o Apple Maps con un
  intent; construir turn-by-turn es exactamente la clase de función que la visión
  descarta.
- **Mapas offline descargables por zona.** Ver comportamiento sin señal.
- **Geocodificar la dirección automáticamente.** Convertir "9800 Georgia Ave" en
  coordenadas necesita un servicio de geocoding con su costo y su cuota; se decide
  con el ADR del proveedor y puede entrar después. El punto se fija a mano.
- **El marcaje de asistencia en sí.** Este spec llena los campos que la geocerca
  necesita; evaluar y mostrar la bandera es del spec de asistencia.

## Dónde está la línea con "Qué NO somos"

La visión descarta dos cosas que este spec roza, así que queda explícito:

> **"No hacemos tracking continuo de ubicación. Solo el punto de clock-in y
> clock-out."**

Se respeta. La ubicación del dispositivo se lee **una vez, y solo cuando alguien
toca "usar mi ubicación"**. No hay suscripción a cambios de posición, ni servicio en
segundo plano, ni permiso de ubicación *always*: alcanza `whileInUse`.

> **"Mapa en vivo, firma de documentos y medición con cámara son años de desarrollo
> que no se alcanzan y no hacen falta."**

También se respeta, y es la distinción que importa: el mapa en vivo de CompanyCam
muestra **gente moviéndose**. Este muestra **un lugar quieto** — una propiedad, su
punto y su círculo. Ninguna pantalla de este spec dibuja una persona.

Si en algún momento se pide ver dónde está la cuadrilla ahora, eso **no es este
spec** y necesita cambiar la visión primero.

## Modelo de dominio afectado

- [[../../../domain/cliente|cliente]] — se escriben `site.lat`, `site.lng` y
  `site.geofence_radius_m`, que ya están en la ficha y en la tabla.

No se agrega nada al modelo.

## Las reglas del dominio que aplican

- **La geocerca pertenece al sitio, no al proyecto.** El mismo cliente puede tener
  tres trabajos en la misma casa: se fija una vez y las tres obras la comparten.
  Cambiar el punto afecta a todas, y eso es lo correcto.
- **`geofence_radius_m` nulo usa el default de la empresa.** Dejarlo sin tocar es una
  opción válida y no un formulario incompleto.
- **La regla 11 no se toca acá.** `is_mock_location` es del marcaje, no de fijar el
  punto de una propiedad: si alguien falsea el GPS al cargar una obra, lo que sale
  mal es la geocerca de esa obra, y eso se corrige a mano. La bandera sigue siendo
  del `time_entry`.
- **Borrado suave y sincronización.** El punto viaja por `site.update`, que ya
  existe (SPEC-0006). Última escritura gana.

## Comportamiento sin señal

Es el punto que decide el proveedor de mapas, y hay que ser honesto: **un mapa sin
red no dibuja nada**, porque los tiles se descargan.

| Situación | Comportamiento |
|---|---|
| Fijar el punto sin señal | **Funciona.** El GPS es del dispositivo y no necesita red. Se guarda local y se encola con `site.update`. |
| Ver el mapa sin señal | Los tiles que ya se vieron salen del caché; lo que no, no se dibuja. La pantalla **dice que falta la red**, no se queda en gris sin explicación. |
| Ver la propiedad sin tiles | Se muestran la dirección, las coordenadas y el radio en texto. Es lo que permite dictarle la ubicación a alguien por teléfono. |
| Abrir en la app de mapas | Depende de esa app, no de esta. Se ofrece igual: Google Maps guarda sus propias descargas. |
| Corregir el radio sin señal | Funciona: es un número, y el círculo se dibuja sobre lo que haya de mapa. |

**Lo pendiente se ve**, como en todo lo que sincroniza: una propiedad con punto sin
subir lleva su marca.

## UI

Sobre la ficha de propiedad que SPEC-0006 ya dejó:

- La propiedad **sin punto** muestra un bloque con la invitación a fijarlo. Es el
  estado normal de todo lo cargado hasta hoy, así que no puede leerse como un error.
- La propiedad **con punto** muestra el mapa en un alto acotado, con el marcador y el
  círculo del radio.
- **Fijar el punto es una pantalla completa**, no un mapa embebido de 200px: se hace
  con el pulgar, arrastrando, y necesita el ancho.
- La acción de fijar es la primaria de esa pantalla y usa `FieldActionButton`: se
  toca parado en la obra, con guantes.
- El radio se ajusta con un control que **mueve el círculo mientras se arrastra**. Un
  campo numérico de metros no dice nada: nadie sabe cuánto es 150.

## Prerequisitos

**Hace falta un ADR de proveedor de mapas antes de implementar.** Es una decisión que
no se revierte en una tarde: cambia dependencias nativas, claves de API, costos por
carga y el comportamiento sin señal.

Lo que hay que comparar, con el offline como criterio de peso:

| Opción | A favor | En contra |
|---|---|---|
| `flutter_map` sobre OpenStreetMap | Sin clave de API, sin costo por carga, tiles cacheables | Menos pulido, y el uso de los tiles públicos de OSM tiene política propia |
| `google_maps_flutter` | El mapa que la gente reconoce, buen soporte | Clave, facturación habilitada, y sin red no dibuja |
| Mapbox | Tier gratis amplio, buen control de estilo | Clave y dependencia de un tercero más |

Además hace falta `geolocator` para leer la posición una vez, que **el frente de
campo va a necesitar igual** para el marcaje. Conviene elegirlo acá y que asistencia
lo herede, en vez de al revés.

Y el permiso de ubicación necesita su texto de justificación en iOS y Android. Eso
se cruza con un pendiente ya registrado en `DECISIONES.md`: *"consentimiento firmado
de ubicación para los trabajadores, en el onboarding"*. Este spec lee la ubicación
**de quien carga la obra**, no de un trabajador vigilado, pero el texto del permiso
tiene que decir la verdad de para qué se usa.

## Criterios de aceptación

- [ ] Una propiedad sin punto se puede fijar desde su ficha, y queda con `lat`,
      `lng` guardados y visibles.
- [ ] "Usar mi ubicación" lee la posición **una sola vez**: no hay stream de
      posición ni permiso de ubicación en segundo plano en el manifiesto.
- [ ] Fijar el punto **sin señal** funciona y llega al servidor por `site.update`
      cuando vuelve la red, sin duplicar.
- [ ] Sin red, la pantalla del mapa dice que falta la red y muestra la dirección y
      las coordenadas en texto — no queda en gris.
- [ ] Ajustar el radio mueve el círculo en pantalla mientras se arrastra.
- [ ] Un radio sin tocar deja `geofence_radius_m` nulo, y eso es válido.
- [ ] Cambiar el punto de una propiedad se refleja en todas las obras de ese sitio,
      porque la geocerca es del sitio.
- [ ] Ninguna pantalla de este spec dibuja la posición de una persona.
- [ ] La dirección se abre en la app de mapas del teléfono desde la ficha.
- [ ] La pantalla se ve correcta en claro y en oscuro, y hay un solo naranja sólido.
- [ ] Cero cadenas quemadas, en `en` y `es`, incluidos los textos del permiso de
      ubicación y el mensaje de mapa sin red.

## Riesgos / consideraciones

**El mapa es la primera dependencia que no funciona sin red.** Todo lo construido
hasta ahora anda igual con señal y sin ella; esto no puede. El riesgo no es técnico
sino de expectativa: si la pantalla se ve rota sin cobertura, contradice la promesa
del producto. Por eso el estado sin red es criterio de aceptación y no un detalle.

**El punto fijado con el GPS del teléfono tiene error de metros**, y en un lote
grande eso decide si un marcaje cae dentro o fuera. Poder corregirlo arrastrando no
es un lujo: es lo que evita que la geocerca quede mal calibrada para siempre.

**Fijar la geocerca es lo que le da poder real a la bandera de asistencia.** Vale
tenerlo presente al elegir el default del radio: muy chico y todos aparecen "fuera de
la obra", muy grande y la geocerca no dice nada. Conviene mirar con William qué radio
tiene sentido en sus obras antes de fijar un default de empresa.

**Este spec no valida direcciones.** Un punto puede quedar a cien kilómetros de la
dirección escrita y nada lo detecta. Geocodificar permitiría advertirlo; queda
afuera a propósito, pero es la razón más fuerte para volver a considerarlo.

## ADRs relacionados

- **Pendiente**: proveedor de mapas y librería de ubicación. Es prerequisito de la
  implementación, no de la aprobación de este spec.
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — la acción de
  campo va a 64dp, que es la de fijar el punto

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-10 | borrador | Creado. Sale de la ficha de propiedad de SPEC-0006, que dejó `lat`, `lng` y el radio afuera por ser de asistencia. Verificado contra el gate duro de la visión: no contradice "no tracking continuo" ni "mapa en vivo", y la sección que traza esa línea es parte del spec para que no se derive después. El proveedor de mapas queda como ADR prerequisito. |
