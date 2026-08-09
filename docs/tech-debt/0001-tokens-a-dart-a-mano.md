---
id: DEBT-0001
title: "Los tokens se traducen a Dart a mano, sin generador"
aliases:
  - "DEBT-0001: Los tokens se traducen a Dart a mano, sin generador"
type: tech-debt
status: backlog
severity: media
origin: "ADR-0009"
apps:
  - mobile
trigger: "El scaffold de apps/web, cuando aparezca el segundo consumidor de tokens"
created: 2026-08-08
updated: 2026-08-08
tags:
  - tech-debt
  - tech-debt/backlog
  - ui
---

# DEBT-0001: Los tokens se traducen a Dart a mano, sin generador

## Contexto

Sale de la decisión 5 del [[../adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]].

`design-tokens.json` en la raíz es la fuente única de colores, espaciado, radios y
tipografía para las tres superficies. La solución a término es generar cada formato
desde ese archivo con Style Dictionary.

Hoy hay un solo consumidor —`apps/mobile`— y `apps/web` no tiene scaffold. Montar
el pipeline ahora significaría generar un único archivo que igual habría que
revisar a mano, con un prototipo comprometido para la semana del 2026-08-10.

## Qué no se hizo

No existe generación automática de tokens. `apps/mobile/lib/core/theme/tokens.dart`
está escrito a mano, copiando los valores de `design-tokens.json`.

Nada valida que los dos archivos coincidan: se puede cambiar un color en el JSON y
que la app siga compilando con el valor viejo, sin ningún aviso.

## Workaround actual

El JSON manda y es lo que se edita primero; `tokens.dart` se actualiza en el mismo
commit. Es vivible porque hoy hay un solo destino y un solo desarrollador tocando
el tema, así que la ventana entre editar uno y el otro se mide en minutos.

## Costo de resolverla

Bajo, entre dos y cuatro horas: agregar Style Dictionary como paquete del workspace,
escribir el formato de salida para Dart y otro para SCSS, y conectarlo a un script
`tokens:generate` en la raíz, junto a `contracts:generate`.

Se toca `packages/`, el `package.json` de la raíz y `lib/core/theme/tokens.dart`,
que pasa de escrito a generado.

## Costo de NO resolverla

Crece con cada superficie. Con una, es una copia manual que se ve en el diff. Con
`apps/web` viva son dos destinos a sincronizar a mano, y ahí la deriva visual entre
Angular y Flutter deja de ser hipótesis: es el riesgo declarado en el
[[../adr/0002-superficies-flutter-angular/README|ADR-0002]] realizándose por la vía
más tonta, que es alguien olvidando actualizar el segundo archivo.

El modo de fallo es silencioso: no rompe el build, solo hace que un botón sea de un
azul distinto en el teléfono que en el panel.

## Trigger

**El scaffold de `apps/web`.** En cuanto exista un segundo consumidor de tokens, la
generación se paga sola y esta deuda pasa a activa.

Trigger secundario: si alguien reporta que un color no coincide entre superficies,
ya se materializó y sube a activa sin esperar lo otro.

## Propuesta de solución

Style Dictionary sobre `design-tokens.json`, con dos salidas:

- `apps/mobile/lib/core/theme/tokens.dart` — constantes Dart, marcado como generado
- `apps/web/src/styles/tokens/_generated.scss` — variables CSS en `:root` y
  `[data-theme='dark']`

Se engancha a un script `tokens:generate` en la raíz. Igual que con el contrato,
regenerar pasa a ser parte de la definición de "cambio de token terminado", y el
diff del PR delata al que se olvide.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | backlog | Registrada al tomar el ADR-0009 |
