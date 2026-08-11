---
id: SPEC-0007
title: "Ubicación de la propiedad en el mapa"
aliases:
  - "SPEC-0007: Ubicación de la propiedad en el mapa"
type: spec
platform: mobile
status: review
goal: "Una propiedad queda con su punto y su radio de geocerca fijados desde un mapa —tocándolo o usando la posición actual, nunca escribiendo coordenadas a mano— y ese punto es contra el que el marcaje evalúa la geocerca."
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
  - spec/review
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

> **Este spec resuelve la primera mitad, no la segunda.** Fijar el punto es una
> acción de quien administra: la pantalla cuelga de la ficha de propiedad, que está
> detrás de `customers.read` —`OWNER`, `ADMIN` y `ACCOUNTANT`— y cuyo eje en la barra
> solo ven `OWNER` y `ADMIN`. **La cuadrilla no entra ahí y no va a ver este mapa.**
>
> Que el trabajador vea a dónde ir pasa a
> [[../0008-asistencia-en-el-movil/README|SPEC-0008]], que es el spec dueño de la
> pantalla "Hoy" — la única a la que un `WORKER` sí entra. Sin ese reparto, este spec
> prometía en su `goal` algo que su propio alcance no puede entregar, y el mecanismo
> real seguiría siendo el WhatsApp que el párrafo de arriba describe.

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
- **Que el trabajador vea a dónde ir.** Ver el punto de la obra de hoy y abrirla en la
  app de mapas desde la pantalla "Hoy" es de
  [[../0008-asistencia-en-el-movil/README|SPEC-0008]], que es dueño de esa pantalla.
  Acá se llena el dato; allá se muestra a quien lo necesita.

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
- **`geofence_radius_m` nulo es válido**, y dejarlo sin tocar no es un formulario
  incompleto. Las fichas de dominio dicen que entonces se usa "el default de la
  empresa"; **hoy eso no es cierto en el código** —es una constante de 150 metros en
  `time-entries.service.ts` y `company.settings` no se lee—, y quedó registrado en
  [[../../../tech-debt/0004-radio-de-geocerca-hardcodeado|DEBT-0004]]. No bloquea este
  spec: lo que se fija por sitio sí se respeta.
- **La regla 11 no se toca acá.** `is_mock_location` es del marcaje, no de fijar el
  punto de una propiedad: si alguien falsea el GPS al cargar una obra, lo que sale
  mal es la geocerca de esa obra, y eso se corrige a mano. La bandera sigue siendo
  del `time_entry`.
- **Borrado suave y sincronización.** El punto viaja por `site.update`, que ya
  existe (SPEC-0006). Última escritura gana.

## Contrato de API

**No cambia nada.** Verificado contra el código, y por eso queda escrito: a diferencia
de SPEC-0004 y SPEC-0006, este spec **no tiene ningún prerequisito de contrato**.

```http
PATCH /api/customers/:id/sites/:siteId      # customers.write
```

`UpdateSiteDto` ya acepta `lat`, `lng` y `geofenceRadiusM`, la operación `site.update`
ya está en `SYNC_OPERATIONS`, y la tabla local `Sites` ya tiene las tres columnas.

Lo único que falta es del lado del móvil: `CustomerRepository.updateSite()` **los
excluye a propósito**, con un comentario que dice que son de asistencia y entran con
el frente de campo. La implementación de este spec es extender ese método, no crear
uno nuevo.

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

**Resuelto.** [[../../../adr/0012-proveedor-de-mapas/README|ADR-0012]] eligió
**`google_maps_flutter`** sobre los SDK nativos, y **`geolocator`** para leer la
posición — que el frente de campo necesita igual para el marcaje, así que se eligió
acá y SPEC-0008 lo hereda.

Las dos premisas con las que este spec había planteado la comparación resultaron
viejas, y el ADR las corrige con su fuente:

- **Los Maps SDK de Android y de iOS son gratis y sin límite** desde marzo de 2025.
  El costo por carga dejó de ser un criterio.
- **Los tiles públicos de OpenStreetMap no son una opción para un servicio
  comercial.** Su política dice que el acceso puede retirarse sin aviso, y OSM midió
  que `flutter_map` es su mayor consumidor por user-agent.

Lo que este spec necesita del SDK y ya está resuelto: `Circle` toma su `radius` en
**metros**, que es la unidad de `geofence_radius_m`, y `onTap` devuelve el `LatLng`
del toque.

**Geocoding no entra**, y no por el costo: el punto se elige tocando el mapa, y el
caso principal es alguien parado en la obra usando su ubicación actual. Se puede
agregar después sin tocar el modelo — `site.address` ya existe y es obligatorio.

### Lo que hay que tener antes del primer build

- **Clave de API restringida por plataforma**: SHA-1 del certificado en Android,
  bundle id en iOS, y llaves distintas para desarrollo y producción. El mismo criterio
  que ADR-0010 pide para Backblaze, y por la misma razón: una demo no debe poder
  gastar la cuota de producción.
- **El texto del permiso de ubicación en `en` y `es`**, en `Info.plist` y en el
  manifiesto de Android. Tiene que decir la verdad de para qué se usa: acá se lee la
  posición **de quien carga la obra, una sola vez y al tocar el botón**. La del
  trabajador en cada marcaje es SPEC-0008 y es otra cosa.

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
- [ ] **No existe ningún campo de texto para latitud ni longitud** en toda la feature:
      el punto sale del mapa o del GPS, nunca del teclado.
- [ ] Una propiedad con punto sin subir **muestra su marca de pendiente**, como el
      resto de lo que sincroniza.
- [ ] Un `FOREMAN` y un `WORKER` **no** tienen forma de llegar a esta pantalla, que
      cuelga de la ficha de propiedad. Es lo que hace que el `goal` se limite a fijar
      el punto y no a mostrárselo a la cuadrilla.
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

- [[../../../adr/0012-proveedor-de-mapas/README|ADR-0012]] — `google_maps_flutter` y
  `geolocator`, con el porqué de descartar OSM y Mapbox
- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — la acción de
  campo va a 64dp, que es la de fijar el punto
- [[../../../adr/0003-asistencia-geocerca-foto/README|ADR-0003]] — la geocerca que
  este spec vuelve verificable

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-10 | review | Prerequisito resuelto por [[../../../adr/0012-proveedor-de-mapas/README|ADR-0012]]: `google_maps_flutter` y `geolocator`. **Las dos premisas de la comparación que este spec había planteado eran viejas** — los SDK móviles de Google son gratis y sin límite desde marzo de 2025, y los tiles públicos de OSM no son una opción para un servicio comercial porque su política permite retirar el acceso sin aviso. Geocoding queda afuera por decisión, no por costo. Se agregó lo que hay que tener antes del primer build: la clave restringida por plataforma y el texto del permiso de ubicación en los dos idiomas. |
| 2026-08-10 | borrador | Creado. Sale de la ficha de propiedad de SPEC-0006, que dejó `lat`, `lng` y el radio afuera por ser de asistencia. Verificado contra el gate duro de la visión: no contradice "no tracking continuo" ni "mapa en vivo", y la sección que traza esa línea es parte del spec para que no se derive después. El proveedor de mapas queda como ADR prerequisito. |
