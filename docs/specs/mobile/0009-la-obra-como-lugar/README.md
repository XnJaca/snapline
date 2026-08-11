---
id: SPEC-0009
title: "La obra como lugar, no como botón"
aliases:
  - "SPEC-0009: La obra como lugar, no como botón"
type: spec
platform: mobile
status: borrador
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
  - spec/borrador
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
- **Tocar una obra abre su pantalla, con tabs** — el mismo patrón del detalle
  de obra del OWNER, con el contenido del campo:
  - **[Registro]** — la acción y la historia en un solo lugar. Marcar entrada
    despliega el cronómetro con su obra y su ánimo; abajo, las jornadas de esa
    obra como **lista colapsable**: cerrada muestra fecha y horas trabajadas,
    abierta muestra el detalle — a qué hora entró, a qué hora salió, el total,
    sus banderas y su estado de aprobación.
  - **[Detalle]** — la dirección, el punto en Mapas, el cliente no (la cuadrilla
    no navega cartera: solo el lugar).
- "Mi semana" como pantalla aparte desaparece: su contenido vive en el resumen
  del home y en el Registro de cada obra.

**Para el foreman, además:**

- **La pestaña Cuadrilla es una lista de cuadrillas** — las que lidera o
  integra. Con una sola, se entra directo.
- **Tocar una cuadrilla abre su pantalla, con tabs:**
  - **[Personas]** — lo que hoy es la pantalla de cuadrilla: quién está adentro,
    quién salió, quién no marcó, marcar por otro y "Otra persona…". Sin cambios
    de comportamiento.
  - **[Horas]** — el acumulado de la semana por persona, sumado de las jornadas
    que ya bajan al teléfono. Solo lectura: aprobar sigue siendo de la oficina.

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

## Comportamiento sin señal

Idéntico a SPEC-0008 — esta reorganización no agrega ninguna lectura de red:

| Situación | Comportamiento |
|---|---|
| Abrir Obras / la obra / Registro | Todo sale de Drift, como siempre |
| Marcar desde el tab Registro | El mismo camino de SPEC-0008, sin cambios |
| El desglose de jornadas | Local; las banderas y aprobaciones llegan por el pull |
| Horas por persona (foreman) | Suma local de lo que ya baja |

## Criterios de aceptación

- [ ] El eje se llama "Obras" en `en` y `es`, y lista las obras de hoy con
      dirección; el resumen semanal propio encabeza la lista.
- [ ] Tocar una obra abre su pantalla con tabs Registro y Detalle; el marcaje
      vive en Registro y funciona exactamente como en SPEC-0008 (los tests de
      marcaje siguen pasando sin cambios de lógica).
- [ ] Una jornada pasada colapsada muestra fecha y total; expandida muestra
      entrada, salida, total, banderas y estado.
- [ ] Con una sola obra asignada, el flujo de marcar no requiere más toques que
      antes (obra → Registro ya abierto → botón).
- [ ] La pestaña Cuadrilla lista cuadrillas; con una sola entra directo; adentro,
      Personas se comporta idéntico a hoy y Horas muestra el acumulado semanal
      por persona.
- [ ] "Mi semana" no existe más como pantalla; nada de su información se perdió.
- [ ] Cero cadenas quemadas en `en` y `es`; ambos temas; ningún valor de estilo
      literal.

## Riesgos / consideraciones

- **Un toque más para marcar.** Antes: abrir la app → botón. Ahora: abrir →
  obra → botón. Con una sola obra el Registro abre directo, así que el costo
  real es cero en el caso común; con varias, elegir la obra ya era necesario.
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
| 2026-08-11 | borrador | Creado desde la prueba en teléfono de SPEC-0008: "la obra debe ser un lugar, no un botón". Incidentes queda nombrado como futuro y fuera: es dominio nuevo y necesita su ficha primero. El tab "Otros" se descartó — un cajón sin definición nace vacío y muere lleno. |
