---
id: ADR-0003
title: "Asistencia verificada con geocerca y foto, sin bloquear al trabajador"
aliases:
  - "ADR-0003: Asistencia verificada con geocerca y foto, sin bloquear al trabajador"
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

# ADR-0003: Asistencia verificada con geocerca y foto, sin bloquear al trabajador

## Contexto

William tiene dos cuadrillas y no sabe cuántos mandó a cada proyecto, no controla
horas ni asistencia, y junta todo a mano para el contador. Su pregunta textual fue
cómo saber si el trabajador **realmente se presentó**.

Cualquier mecanismo de verificación se topa con tres cosas: obras sin cobertura,
trabajadores sin voluntad de ser vigilados, y la facilidad de falsear GPS en Android.

## Decisión

Al marcar entrada y salida, la app captura **GPS y una foto**. El servidor calcula
la distancia contra las coordenadas de la obra y registra si cayó dentro del radio.

**No bloquea.** Registra la evidencia y levanta una bandera para que el admin
apruebe o rechace. Funciona sin señal: sella coordenadas y hora en el dispositivo
y sube cuando haya red.

Banderas que levanta el sistema: fuera de geocerca, sin foto, GPS simulado, jornada
mayor a 14 horas, sin marca de salida, editado a mano, dos proyectos solapados.

## Alternativas consideradas

### Alternativa A — QR o NFC fijo en la obra

Un sticker que el trabajador escanea al llegar y al salir.

**Por qué no:** alguien fotografía el QR y marca desde su casa. Más barato en
privacidad, pero la evidencia es más débil que el GPS. Sirve mejor en obras largas
con un punto fijo, que no es el caso de un contratista residencial.

### Alternativa B — Check-in del foreman por cuadrilla

El jefe de cuadrilla marca a los suyos de una vez.

**Por qué no:** resuelve el dolor de "cuántos mandé" con una sola acción, pero
traslada toda la confianza al foreman y no sirve como evidencia individual en una
disputa de horas. Queda disponible como método secundario, no como el principal.

### Alternativa C — Bloquear si está fuera de la geocerca

**Por qué no:** un trabajador que no puede fichar deja de usar la app el primer
día, y ahí se cae el frente entero. El GPS falla en sótanos y bajo techos metálicos
con más frecuencia de la que se cree; castigar al trabajador por eso es castigar al
usuario por una limitación nuestra.

## Consecuencias

### Positivas

- William obtiene evidencia real sin convertirse en vigilante.
- La foto de marcaje sirve doble: verifica presencia y alimenta el contenido.
- Marcar nunca falla, así que la adopción no depende de la cobertura.

### Negativas / Costos

- La aprobación de horas es trabajo humano recurrente para el admin.
- Guardar ubicación de empleados es dato sensible, con obligaciones que lo acompañan.

### Riesgos

- **GPS falseable.** Android permite simular ubicación con una app gratis.
  Mitigación: `is_mock_location` se guarda siempre; sin esa bandera la geocerca es
  teatro. Y el servidor **recalcula** la distancia — nunca acepta del dispositivo
  la bandera de "estaba dentro".
- **Consentimiento.** Registrar GPS de empleados requiere consentimiento informado
  y por escrito. Mitigación: va firmado en el onboarding, no en un checkbox enterrado.
- **`device_recorded_at` es manipulable** porque lo provee el dispositivo.
  Mitigación: el servidor lo acota y marca lo que quede fuera de rango razonable.

## Impacto en el modelo

- [[../../domain/registro-de-tiempo|registro-de-tiempo]]
- [[../../domain/cuadrilla|cuadrilla]]
- [[../../domain/proyecto|proyecto]]

## Referencias

- Reunión con William del 2026-08-08.
