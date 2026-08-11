---
id: ADR-0012
title: "Google Maps para el mapa del móvil"
aliases:
  - "ADR-0012: Google Maps para el mapa del móvil"
type: adr
status: propuesto
supersedes: null
superseded_by: null
related_specs: ["SPEC-0007", "SPEC-0008"]
created: 2026-08-10
updated: 2026-08-10
deciders:
  - jaca
tags:
  - adr
  - adr/propuesto
---

# ADR-0012: Google Maps para el mapa del móvil

> **Meta**
> - Deciders: @jaca

## Contexto

[[../../specs/mobile/0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]] no
se puede implementar sin elegir esto, y
[[../../specs/mobile/0008-asistencia-en-el-movil/README|SPEC-0008]] no se puede
implementar sin SPEC-0007: sin el punto de la propiedad, `evaluateGeofence` compara
contra `null` y la geocerca no evalúa nada. **Es el cuello de botella del frente de
campo entero.**

Lo que el mapa tiene que hacer es corto y no va a crecer: mostrar una propiedad,
fijarle un punto tocando la pantalla o con la ubicación actual, y dibujar el círculo
del radio de geocerca mientras se arrastra. Nada más — SPEC-0007 descarta
explícitamente la navegación dentro de la app, los mapas offline descargables y ver
personas en el mapa.

El volumen también es corto: un contratista con veinte propiedades abre este mapa unas
pocas decenas de veces por mes, y **una propiedad se fija una vez**. Cualquier
esquema de precios por carga es gratis a esta escala, así que el costo no decide.

Lo que sí decide: qué se puede usar sin que lo apaguen, cuánta fricción de setup suma,
y qué pasa el día que el volumen deje de ser corto.

## Decisión

**`google_maps_flutter`, el plugin oficial, sobre el Maps SDK de Android y de iOS.**
Y **`geolocator`** para leer la posición, elegido acá y heredado por SPEC-0008, que lo
necesita igual para el marcaje.

La razón de peso apareció verificando precios y no estaba en el análisis de SPEC-0007:
**desde marzo de 2025 los Maps SDK de Android y de iOS son gratis y sin límite de
uso.** Google retiró ese mes el crédito universal de USD 200 y lo reemplazó por cupos
gratis por SKU —10.000 llamadas para Essentials, 5.000 para Pro, 1.000 para
Enterprise—, y en ese movimiento **dejó los SDK móviles fuera de la facturación por
completo**. Snapline usa exactamente eso y nada más.

Cubre lo que SPEC-0007 pide, sin extensiones: `Circle` toma su `radius` en metros
—que es la unidad de `geofence_radius_m`—, `onTap` devuelve el `LatLng` del toque, y
los marcadores son parte del widget.

## Alternativas consideradas

### Alternativa A — `flutter_map` sobre los tiles públicos de OpenStreetMap

Es la que SPEC-0007 anotó como "sin clave de API, sin costo por carga". Suena a la
opción libre y no lo es.

**Por qué no:** los datos de OSM son libres; **sus servidores de tiles no**. Se
financian con donaciones, no tienen SLA, y su política dice que a un servicio
comercial el acceso **puede retirársele en cualquier momento y sin aviso**. Construir
la única pantalla que necesita red sobre algo que puede apagarse un martes es aceptar
una falla que no se puede diagnosticar desde acá.

Y hay un agravante concreto: en junio de 2025 OSM midió que **`flutter_map` es el
mayor consumidor de tiles por user-agent** de toda la plataforma. El propio paquete
muestra una advertencia al respecto. Es el cliente más vigilado sobre el servicio más
frágil.

Sigue siendo una salida válida **con un proveedor de tiles propio o de pago**, y por
eso importa que lo que se guarda —`lat`, `lng`, `geofence_radius_m`— no tenga nada del
proveedor adentro. Ver los riesgos.

### Alternativa B — Mapbox

25.000 usuarios activos mensuales gratis, buen control de estilo, y **tiles offline
descargables**, que es su ventaja real sobre Google.

**Por qué no:** esa ventaja está explícitamente fuera del alcance. SPEC-0007 descarta
los mapas offline descargables por zona y ya resolvió el comportamiento sin señal por
otro camino —tiles cacheados, y si no hay, la dirección y las coordenadas en texto.
Pagar esa ventaja con un proveedor más, una cuenta más y una tarjeta más es comprar lo
que se decidió no usar.

Queda como el reemplazo natural si alguna vez hace falta mapa offline de verdad.

### Alternativa C — Apple MapKit

**Por qué no:** solo iOS. La app es iOS **y** Android, y mantener dos mapas distintos
por plataforma duplica el trabajo de una pantalla que se escribe una vez.

## Consecuencias

### Positivas

- **Costo cero y sin cupo** en lo que la app usa, sin depender de que un crédito
  mensual alcance.
- **Es el mapa que la gente reconoce**, y en Android es el mismo al que SPEC-0007
  delega el "cómo llego". Fijar el punto y después abrir la navegación no cambia de
  lenguaje visual a mitad de camino.
- Plugin oficial del equipo de Flutter, con `Circle`, `onTap` y marcadores resueltos.
- Un solo proveedor nuevo, y `geolocator` queda elegido para los dos specs del frente.

### Negativas / Costos

- **Hace falta una cuenta de Google Cloud con facturación habilitada**, aunque el SDK
  no cobre. Es una tarjeta cargada en una cuenta para usar algo gratis, y es fricción
  real de setup.
- **El día que entre geocoding, deja de ser gratis.** Convertir "9800 Georgia Ave" en
  coordenadas es un SKU Essentials: 10.000 llamadas gratis por mes y después entre USD
  2 y 7 por millar. A este volumen es gratis en la práctica, pero ya no es "sin
  factura posible". SPEC-0007 lo dejó fuera de alcance y anotó que se decidía acá:
  **entra después, con su propio cupo vigilado.**
- **Sin red no dibuja**, lo mismo que cualquier proveedor sin descarga offline.
- La clave viaja en el binario.

### Riesgos

- **Google ya cambió su modelo de precios una vez, en marzo de 2025.** Puede volver a
  hacerlo, y el "gratis sin límite" de los SDK móviles es una decisión suya, no un
  contrato. Mitigación: el uso está encerrado en una pantalla y **lo que se persiste
  es del dominio, no del proveedor** — `lat`, `lng` y `geofence_radius_m` son tres
  números que cualquier mapa dibuja. Cambiar a `flutter_map` con otro proveedor de
  tiles toca una pantalla, no el modelo ni el contrato.
- **La clave sin restringir se usa desde cualquier lado.** Mitigación: se restringe
  por plataforma —SHA-1 del certificado en Android, bundle id en iOS— antes del primer
  build que salga de la máquina de desarrollo, y las claves de desarrollo y producción
  son distintas, con el mismo criterio que ADR-0010 pide para Backblaze.
- **El permiso de ubicación tiene que decir la verdad de para qué se usa.** Acá se lee
  la posición de quien carga la obra, una sola vez y solo al tocar el botón; en
  SPEC-0008 se lee la de un trabajador en cada marcaje, que es otra cosa. Se cruza con
  el consentimiento firmado que [[../../DECISIONES|DECISIONES]] tiene pendiente.

## Qué lo revierte

- Que haga falta **mapa offline descargable por zona** — obras en zonas sin cobertura
  donde ver el terreno importe. Ahí gana Mapbox y este ADR queda superseded.
- Que Google **vuelva a mover los SDK móviles a facturación**.
- Que aparezca la necesidad de **ver gente en el mapa**, que hoy la visión descarta y
  que cambiaría los requisitos de raíz.

## Impacto en el modelo

- [[../../domain/cliente|cliente]] — se escriben `site.lat`, `site.lng` y
  `site.geofence_radius_m`, que ya están en la ficha y en la tabla. **No se agrega
  nada al modelo.**
- [[../../specs/mobile/0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]] —
  lo desbloquea
- [[../../specs/mobile/0008-asistencia-en-el-movil/README|SPEC-0008]] — hereda
  `geolocator` y depende de que la geocerca tenga punto contra el cual evaluar
- [[../0003-asistencia-geocerca-foto/README|ADR-0003]] — la geocerca que este ADR
  vuelve verificable

## Referencias

- [Tile usage policy — OpenStreetMap Foundation](https://operations.osmfoundation.org/policies/tiles/)
- [Using OpenStreetMap (direct) — flutter_map Docs](https://docs.fleaflet.dev/tile-servers/using-openstreetmap-direct)
- [Maps SDK for Android: usage and billing — Google](https://developers.google.com/maps/documentation/android-sdk/usage-and-billing)
- [Google Maps Platform pricing](https://mapsplatform.google.com/pricing/)
- [Pricing by products — Mapbox](https://docs.mapbox.com/accounts/guides/pricing/)
