---
id: SPEC-0009
title: "La obra como lugar, no como botón"
aliases:
  - "SPEC-0009: La obra como lugar, no como botón"
type: spec
platform: mobile
status: en-implementacion
goal: "El trabajador entra a su obra y ahí adentro marca, ve su registro con cada jornada desglosada y el detalle del lugar; el foreman entra a su cuadrilla y ve a su gente con sus horas — las pestañas Obras y Cuadrilla son listas de lugares, no pantallas de acción."
apps:
  - mobile
depends_on:
  - "0008-asistencia-en-el-movil"
domain:
  - registro-de-tiempo
  - cuadrilla
  - proyecto
frente: campo
created: 2026-08-11
updated: 2026-08-11
tags:
  - spec
  - spec/en-implementacion
  - mobile
---

# SPEC-0009: La obra como lugar, no como botón

> **Meta**
> - Apps afectadas: `mobile`
> - Depende de: [[../0008-asistencia-en-el-movil/README|SPEC-0008]]
> - Frente: `campo`

---

## Problema

Salió de probar SPEC-0008 en un teléfono real, el mismo día: la pantalla Hoy
muestra *"Techo Martinez → [Marcar entrada]"* y se siente un botón suelto, no un
lugar de trabajo. La decisión de producto textual:

> "Es mejor que muestre las obras, el usuario toque la obra, y ahí pueda ver en
> tabs lo que corresponde."

La obra es donde pasan las cosas —el marcaje, el registro, mañana los
incidentes y las fotos— y hoy no tiene hogar en la vista del trabajador. El
OWNER ya lo tiene: su detalle de obra con tabs existe desde SPEC-0003. Esta es
la misma idea para el campo.

**Nada de la lógica cambia.** El marcaje que nunca falla, la escalera de
evidencia, los conflictos y la subida de fotos son de SPEC-0008 y quedan
intactos: esto reorganiza dónde viven.

## Alcance

### Entra

**Para quien trabaja (`WORKER` y `FOREMAN`):**

- **El eje "Hoy" pasa a llamarse "Obras"** y es una lista de lugares: las obras
  con asignación de hoy, cada una con su dirección y su camino a Mapas. Arriba,
  el resumen de la semana propia (horas acumuladas), que hoy vive escondido en
  "Mi semana".

  **"La semana"**, acá y en todo este spec, es la ventana rodante de los últimos
  7 días — la misma convención que "Mi semana" de SPEC-0008, no la semana
  calendario. La jornada abierta cuenta en vivo, hasta el momento de mirar.
- **Tocar una obra abre su pantalla, con tabs** — el mismo patrón del detalle
  de obra del OWNER, con el contenido del campo:
  - **[Registro]** — la acción y la historia en un solo lugar. El botón dice de
    quién es la acción — **"Marcar mi entrada"** — porque quien puede marcar
    por otros necesita saber que este tab es el propio. Marcar despliega el
    cronómetro con su obra y su ánimo; abajo, las jornadas de esa obra como
    **lista colapsable**: cerrada muestra fecha y horas trabajadas, abierta
    muestra el detalle — a qué hora entró, a qué hora salió, el total, sus
    banderas y su estado de aprobación.
  - **[Cuadrilla]** — solo para quien tiene `crews.read` (foreman, OWNER,
    ADMIN): la gente de ESTA obra, con marcar por otro y "Otra persona…" — la
    misma pantalla del eje Cuadrilla, fijada a la obra en la que se está. El
    permiso lo dice el servidor; el móvil no replica la tabla de roles.
  - **[Detalle]** — la ficha del lugar: estado, dirección, tipo de trabajo,
    fecha de inicio, fecha objetivo y descripción — **solo lo que ya baja al
    teléfono**. El cliente no (la cuadrilla no navega cartera). **Fases
    tampoco, todavía**: no existen en el dominio — el día que se quieran,
    primero su ficha en `docs/domain/`, después su spec.

**Jornada abierta en otra obra.** El invariante del dominio es global — no puede
haber dos registros abiertos del mismo membership — y la estructura por-obra
hace este caso alcanzable: entrar al Registro de la obra B con la jornada
abierta en la A. Ahí no se puede marcar ni entrada (ya hay una) ni salida (es de
otro lugar): el botón no aparece y en su lugar un aviso dice **en qué obra** está
la jornada abierta y que hay que cerrarla allá. Es el mismo precedente de
SPEC-0008 —que ocultaba el selector de obra con jornada abierta— y no viola la
regla 9: el marcaje que se bloquea acá es el que produciría un segundo `clockIn`
condenado a `CONFLICT`; marcar donde corresponde sigue sin poder fallar.

Y para que eso sea verdad, **la obra con la jornada abierta aparece siempre en
la lista de Obras, aunque ya no tenga asignación hoy**, marcada como tal. El
caso es real: la jornada quedó abierta ayer y hoy lo cambiaron de obra. Si la
lista fuera solo la asignación de hoy, el aviso nombraría un lugar al que la
app no da ningún camino — y cerrar la jornada sí podría fallar.
- "Mi semana" como pantalla aparte desaparece: su contenido vive en el resumen
  del home y en el Registro de cada obra.

**Para el foreman, además:**

- **La pestaña Cuadrilla es una lista de cuadrillas** — las que lidera o
  integra. **Siempre la lista, aunque haya una sola**: el atajo de entrar
  directo se probó y se descartó — caer de una en el detalle se sentía como
  una pantalla que nadie pidió. El toque de más compra saber dónde se está.
- **Tocar una cuadrilla abre su pantalla, con tabs:**
  - **[Personas]** — lo que hoy es la pantalla de cuadrilla: quién está adentro,
    quién salió, quién no marcó, marcar por otro y "Otra persona…". Sin cambios
    de comportamiento.
  - **[Horas]** — el acumulado de la semana por persona, sumado de las jornadas
    que ya bajan al teléfono. Solo lectura: aprobar sigue siendo de la oficina.

    Ese acumulado **puede subestimar**: al teléfono del foreman solo bajan las
    jornadas de las obras donde él mismo está asignado (prerequisito 3 de
    SPEC-0008). Si alguien de su cuadrilla trabajó la semana en una obra ajena
    al foreman, esas horas no aparecen. Es una vista de campo, no el reporte de
    nómina — el número autoritativo sigue siendo el de la oficina.

### No entra

- **Incidentes.** Se nombra acá porque es el destino natural de un tab futuro,
  pero es un **agregado nuevo del dominio** — sin ficha, sin tabla, sin reglas.
  Cuando se quiera, primero `/domain-new`, después su spec. Ningún tab
  placeholder vacío mientras tanto: un tab sin contenido es una promesa rota en
  la primera impresión.
- Ningún tab "Otros": un cajón sin definición nace vacío y muere lleno.
- Cambios en el marcaje, la escalera, los conflictos o las subidas — son de
  SPEC-0008 y no se tocan.
- Las pestañas del OWNER/ADMIN. Su detalle de obra ya existe y no cambia.

## Lo que esto toca de SPEC-0003

La arquitectura de navegación fijó los ejes por rol y sus nombres. Este spec
**renombra el eje** (`Hoy` → `Obras`, clave `navToday` → el label cambia, la
ruta puede quedar) y convierte dos ejes-pantalla en ejes-lista con detalle
pushed. La estructura de ramas del shell no cambia; los criterios de SPEC-0003
sobre cantidad de ejes por rol siguen valiendo tal cual.

Un criterio de SPEC-0003 merece mención aparte: *"un WORKER ve exactamente dos
y ninguna es la cartera"* descansaba en "su día es una obra", en singular, y
este spec vuelve el eje explícitamente plural. **El invariante de fondo no
cambia y el test queda como está**: Obras lista solo las asignaciones de hoy —
nunca la cartera completa de proyectos de la empresa, que sigue siendo del
OWNER/ADMIN. Lo que era singular era el label, no el límite de visibilidad.

## Comportamiento sin señal

Idéntico a SPEC-0008 — esta reorganización no agrega ninguna lectura de red:

| Situación | Comportamiento |
|---|---|
| Abrir Obras / la obra / Registro | Todo sale de Drift, como siempre |
| Marcar desde el tab Registro | El mismo camino de SPEC-0008, sin cambios |
| El desglose de jornadas | Local; las banderas y aprobaciones llegan por el pull |
| Horas por persona (foreman) | Suma local de lo que ya baja |
| Jornada abierta en otra obra | Sin botón de marcar; un aviso nombra la obra donde está abierta. Se decide con datos locales — sin señal funciona igual |

## Criterios de aceptación

- [x] El eje se llama "Obras" en `en` y `es`, y lista las obras de hoy con
      dirección; el resumen semanal propio encabeza la lista.
- [x] Tocar una obra abre su pantalla con tabs Registro y Detalle; el marcaje
      vive en Registro y funciona exactamente como en SPEC-0008 (los tests de
      marcaje siguen pasando sin cambios de lógica).
- [x] Una jornada pasada colapsada muestra fecha y total; expandida muestra
      entrada, salida, total, banderas y estado.
- [x] Con la jornada abierta en otra obra, el Registro de esta no ofrece botón
      de marcar y el aviso nombra la obra donde está abierta.
- [x] El tab Detalle muestra la ficha del lugar — estado, dirección, tipo de
      trabajo, fechas y descripción, omitiendo lo que no tenga valor — con su
      camino a Mapas, y **ningún dato del cliente**: nombre, teléfono, nada.
- [x] Quien tiene `crews.read` ve el tab Cuadrilla dentro de la obra, fijado a
      esa obra; el WORKER no lo ve.
- [x] El botón del Registro dice "Marcar mi entrada" / "Marcar mi salida": el
      tab es personal y el que marca por otros lo hace desde Cuadrilla.
- [x] Marcar cuesta un toque más que antes — obra → botón, con Registro ya
      abierto como primer tab — y es a propósito: el home es la lista con el
      resumen y la dirección, y **no se salta ni con una sola obra**, porque
      saltarla escondería el resumen en el caso más común.
- [x] La obra con la jornada abierta aparece en la lista de Obras aunque ya no
      tenga asignación hoy, marcada como tal, y desde ahí se marca la salida.
- [x] La pestaña Cuadrilla lista cuadrillas — siempre, aunque haya una sola —
      y el toque abre el detalle; adentro, Personas se comporta idéntico a hoy
      y Horas muestra el acumulado semanal por persona, en cards.
- [x] "Mi semana" no existe más como pantalla: el total vive en el resumen del
      home y el desglose por jornada en el Registro de cada obra (alcanzable
      mientras la obra esté en la lista — ver Riesgos).
- [x] Cero cadenas quemadas en `en` y `es`; ambos temas; ningún valor de estilo
      literal.

## Riesgos / consideraciones

- **Un toque más para marcar, a conciencia.** Antes: abrir la app → botón.
  Ahora: abrir → obra → botón. La lista **no se salta ni con una sola obra** —
  el resumen semanal vive ahí y saltarla lo escondería justo en el caso más
  común. El Registro es el primer tab y abre activo, así que nunca hay que
  elegir tab. Cuadrilla sigue la misma regla: siempre su lista.
- **Nada flota sobre el fondo, y el nombre de la sección tampoco.** Nace
  `SectionCard`: un marco con **banda de fondo arriba** —donde vive el
  label— y el contenido pegado abajo, todo en la misma pieza. Un texto
  suelto sobre el lienzo no se lee como el título de lo que sigue; se lee
  como algo que quedó ahí. Lo usan las seis secciones: "Tu tiempo esta
  semana", "Obras en las que estás asignado hoy", "Tus cuadrillas", "La
  gente de esta obra, hoy", "Horas de esta semana, por persona", "Tus
  jornadas en esta obra", y las dos del Detalle. Adentro, las filas van de
  borde a borde separadas por hairlines — las de obra y cuadrilla en
  `primaryContainer`, color con calidez, nunca el naranja saturado, que
  sigue siendo exclusivo de la acción primaria (la regla del naranja).
- **Las acciones dicen qué hacen, con palabras.** En Personas el icono murió:
  el botón dice "Marcar entrada" o "Marcar salida" según el estado — adentro
  no se ofrece una segunda entrada — y el estado es explícito: "Marcó entrada
  hoy a las 7:02", "Salió hoy a las 15:40", "Sin marcar hoy". Esta app se usa
  sin entrenamiento: un icono que hay que adivinar es un bug de producto.
- **El estado es lectura; la acción es acción.** Van en lados distintos de la
  fila —identidad y estado a la izquierda, botón a la derecha— y no uno
  encima del otro a ancho completo, que los ponía a pelear por el mismo peso.
  En el Detalle, por lo mismo, el estado de la obra es un campo con su
  etiqueta ("Estado") y no un chip suelto arriba de todo.
- **El tiempo se cuenta donde se ganó.** En Obras, el total de la semana con
  un mensaje que rota según las horas; en el Registro de cada obra, el
  acumulado **de esa obra** titulando la sección: "Tu tiempo de esta semana en
  Techo Martinez", con las jornadas que lo suman debajo.
- **El mensaje reconoce el trabajo; nunca mide el rendimiento.** "Vas a buen
  ritmo" se lee como alguien mirando el cronómetro por encima del hombro, y
  esta app la usa quien ya sospecha que lo vigilan. El registro es *suyo* —
  su defensa en una disputa de horas (regla 12)—, así que el mensaje dice eso:
  "Cada minuto que marcás queda guardado", "Tu trabajo no pasa desapercibido",
  "Increíble progreso, se nota el trabajo de esta semana". Ninguno compara,
  ninguno apura, ninguno reprocha al que apenas arranca el lunes.
- **El desglose de una obra que salió de la asignación.** El Registro de cada
  obra muestra sus jornadas de la semana, pero la obra es alcanzable mientras
  esté en la lista — asignada hoy o con la jornada abierta. Las jornadas
  cerradas de una obra que ya no aparece suman al resumen y siguen en el
  teléfono; su desglose reaparece cuando la obra vuelva a asignarse. La vista
  autoritativa de la semana completa es de la oficina, no del teléfono.
- **`navToday` cambia de significado.** Los tests de navegación que afirman el
  label "Hoy" se actualizan en el mismo commit.
- Los widget tests de SPEC-0008 sobre TodayScreen se migran a la pantalla
  nueva: mismos casos, mismo rigor — especialmente "ninguna rama sin fila".

## ADRs relacionados

- [[../../../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]] — el botón de
  campo sigue siendo el de 64dp, ahora dentro del tab Registro

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-11 | en implementación | Cuarta pasada: copy y peso. "La gente de esta obra" suena seco y pasa a "Personas asignadas a esta obra"; el estado deja de competir con el botón en Personas y de flotar como título en el Detalle; y el tiempo se cuenta por obra, con ánimo semanal en el home. |
| 2026-08-11 | en implementación | Tercera pasada: el label con fondo. `ListLabel` + `InfoCard` se funden en `SectionCard` —banda arriba, filas de borde a borde abajo— porque un título sin fondo seguía flotando sobre el lienzo. Ninguna sección de la app queda sin marco. |
| 2026-08-11 | en implementación | Segunda pasada de diseño probando como María: ninguna sección sin nombre y ningún dato suelto, el Detalle se agrupa en "El lugar" y "La obra", y en Personas el icono se reemplaza por botones con palabras y estado explícito con "hoy". |
| 2026-08-11 | en implementación | Tanda de diseño, dictada probando en el teléfono como María: nada flota (resumen y Horas en cards), las tarjetas toman el `primaryContainer` del tema, la lista de cuadrillas no se salta nunca, el foreman gana el tab Cuadrilla dentro de la obra, el botón pasa a "Marcar mi entrada" y el Detalle se llena con la ficha que ya baja (estado, fechas, tipo, descripción). Fases quedan fuera: sin ficha de dominio no se inventan. |
| 2026-08-11 | en implementación | Hallazgos de los revisores incorporados. Del `spec-reviewer`: el caso de jornada abierta en otra obra, la resolución con SPEC-0003, el criterio del tab Detalle y la definición de "semana". Del `code-reviewer` (GRAVE): la obra con jornada abierta entra a la lista sin asignación de hoy — sin eso, cerrar la jornada podía quedar sin camino. El "costo cero" de Riesgos se corrigió: la decisión real es la lista siempre visible, un toque más a conciencia. |
| 2026-08-11 | en implementación | Aprobado de palabra por quien lo diseñó — el spec ES su decisión de producto, dictada probando SPEC-0008. El `spec-reviewer` corre en paralelo y sus hallazgos entran como fixes antes del PR. |
| 2026-08-11 | borrador | Creado desde la prueba en teléfono de SPEC-0008: "la obra debe ser un lugar, no un botón". Incidentes queda nombrado como futuro y fuera: es dominio nuevo y necesita su ficha primero. El tab "Otros" se descartó — un cajón sin definición nace vacío y muere lleno. |
