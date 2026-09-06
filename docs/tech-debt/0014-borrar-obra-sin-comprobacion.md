---
id: DEBT-0014
title: "Borrar una obra no comprueba nada, y evade el invariante del cliente"
aliases:
  - "DEBT-0014: Borrar una obra no comprueba nada"
type: tech-debt
status: backlog
severity: alta
origin: "SPEC-0010"
apps: [api]
trigger: "Cuando se exponga borrar obra en cualquier cliente, o cuando entre la primera empresa real con obras facturadas"
created: 2026-09-05
updated: 2026-09-05
tags:
  - tech-debt
  - tech-debt/backlog
---

# DEBT-0014: Borrar una obra no comprueba nada

## Contexto

[[../specs/web/0010-obras-en-el-panel/README|SPEC-0010]] decidió **no exponer
borrar una obra** en el panel: el dominio ya tiene `CANCELLED`, y la ficha de
[[../domain/proyecto|proyecto]] dice que cancelar no borra nada porque las horas
trabajadas siguen siendo horas pagables. Un botón de borrar al lado de uno de
cancelar son dos caminos para lo mismo, y el que borra es el que no deja rastro.

Pero no exponerlo no es cerrarlo. `domain-guardian` lo revisó el 2026-09-03 y
encontró que el problema es más grave que "queda algo colgando": **es una puerta
trasera contra un invariante que ya vive en la base**.

## Qué no se hizo

`ProjectsService.remove` (`apps/api/src/projects/projects.service.ts`) marca
`deleted_at` y **no comprueba nada, ni cascadea nada**.

**Lo que evade.** El trigger `enforce_customer_no_history`, que trajo
[[../specs/web/0009-clientes-y-propiedades/README|SPEC-0009]] en la migración
`CustomerDeleteGuards`, retiene al cliente mirando `project.deleted_at IS NULL`,
**sin importar el estado de la obra**. Entonces:

1. Un cliente tiene una obra en `IN_PROGRESS`, con horas cargadas y fotos
   publicadas. El trigger lo protege: no se puede borrar.
2. Alguien llama `DELETE /projects/{id}` sobre esa obra, en vez de cancelarla.
3. El trigger deja de verla. El cliente pasa a ser borrable.
4. Al borrarlo, `cascade_customer_site_delete` se lleva también sus propiedades.

El invariante que la ficha de [[../domain/cliente|cliente]] declara —*un cliente
con historia no se borra, en cualquier estado*— queda roto por un camino que
ninguna de las dos fichas nombra.

**Lo que además queda colgando** de la obra borrada, porque nada cascadea:

| Tabla | Qué es |
|---|---|
| `time_entry` | Horas, con `pay_rate_cents` ya congelado (regla 13) |
| `media_asset` | Fotos, que siguen en Backblaze y en la tabla |
| `project_assignment` | Asignaciones de cuadrilla |
| `before_after_pair` | Pares de antes y después |
| `project_update` | La bitácora que ve el cliente en el portal |
| `estimate`, `invoice` | Documentos numerados, incluidas **facturas enviadas** que la regla 16 protege |
| `published_project` | Una obra publicada puede quedar borrada en el panel y **visible en el portafolio público** |

## Workaround actual

**Ningún cliente lo llama.** El panel no expone borrar obra —SPEC-0010 lo decidió
así— y el móvil tampoco. El endpoint existe y está autenticado con
`projects.write`, así que hoy solo lo alcanza alguien con el token de un OWNER o
un ADMIN llamando al API a mano.

Es vivible porque el camino que la gente usa es `CANCELLED`, que sí deja rastro y
no rompe nada. Pero es un workaround por ausencia de consumidor, no por diseño:
el día que una pantalla o un script lo llame, el invariante se cae sin aviso.

## Costo de resolverla

Medio día de API, y hay dos formas:

- **Cerrarlo** — un trigger `BEFORE UPDATE` sobre `project` que impida el borrado
  suave cuando la obra tiene horas, fotos o documentos enviados, más su código de
  error en `ERROR_CODES` y el mapeo en `http-exception.filter.ts`. Es la forma que
  ya usa SPEC-0009 con `enforce_customer_no_history`, así que hay precedente y
  patrón.
- **Retirarlo** — sacar el endpoint del controller. Más barato, y coherente con
  que el dominio diga que la salida es cancelar. Rompe el contrato si algún
  cliente generado lo usa: hoy ninguno.

En los dos casos hay que **corregir también el trigger de SPEC-0009** para que
mire el estado de la obra y no solo su `deleted_at`, o la puerta trasera sigue
abierta por cualquier otro camino que marque `deleted_at`.

## Costo de NO resolverla

Con datos reales adentro, un borrado por API deja al cliente borrable y a sus
propiedades cascadeadas, con horas facturables y facturas enviadas apuntando a
filas que ninguna consulta devuelve. **Eso no se detecta hasta que alguien busca
una factura y no aparece la obra**, que es exactamente el escenario de disputa que
la regla 12 quiere evitar.

Mientras no haya consumidor el riesgo es bajo. El problema es que la ausencia de
consumidor no está protegida por nada: la próxima pantalla que necesite "borrar"
lo va a encontrar disponible y funcionando.

## Trigger

**El primero de estos dos:**

1. **Que alguna pantalla o script vaya a exponer borrar una obra.** Ahí deja de
   ser teórico y se resuelve antes de exponerlo, no después.
2. **La primera empresa real con obras facturadas.** Hoy no hay datos que perder;
   con facturas emitidas, un borrado silencioso pasa de ser feo a ser un problema
   contable.

## Propuesta de solución

Cerrarlo con trigger, siguiendo el patrón de `CustomerDeleteGuards`:

```
enforce_project_no_history  BEFORE UPDATE ON project
  cuando deleted_at pasa de nulo a no nulo
  y existe time_entry / media_asset / estimate o invoice enviados
  → PROJECT_HAS_HISTORY
```

Y en el mismo cambio, ampliar `enforce_customer_no_history` para que una obra
borrada **con historia propia** siga reteniendo a su cliente. Sin eso, cerrar el
borrado de obra tapa la puerta pero deja la ventana.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-09-05 | backlog | Registrada al implementar la tanda 1 de SPEC-0010, que es donde el spec la comprometía. La encontró `domain-guardian` el 2026-09-03 revisando el spec, y `spec-reviewer` la confirmó leyendo el trigger de la migración: no es "queda algo colgando", es un bypass de un invariante que ya vive en la base |
