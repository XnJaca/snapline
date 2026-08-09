---
id: ROADMAP
title: "Roadmap — Snapline"
type: product
status: vigente
created: 2026-08-08
updated: 2026-08-08
tags:
  - product
  - roadmap
---

# Roadmap

Por dónde se parte el trabajo. El alcance completo está definido en [[vision]] y
[[../domain/README|el modelo de dominio]] — acá se decide el **orden**, no el qué.

> El esquema de base de datos se construye **entero desde el inicio**. Lo que se
> parte por fases son las pantallas, no el modelo. Migrar con datos reales adentro
> cuesta cinco veces más.

## Fase 0 — Prototipo · semana del 2026-08-10

**Comprometido con llamada para mostrárselo.** Dos días desde la reestructuración,
así que lo que se acota es el alcance del prototipo, no la fecha.

Lo que demuestra la tesis en el teléfono de William:

1. Crear proyecto con cliente
2. Marcar entrada con geocerca y foto
3. Tomar fotos del proyecto
4. Publicar a su web

Eso cuenta el ciclo completo. Corre sobre el esquema definitivo, así que no es
código desechable.

**Riesgo declarado:** "hacerlo bien desde el inicio" y "entregar en dos días" son
incompatibles. Se resuelve acotando qué significa prototipo, no bajando la calidad
del esquema.

## Fase 1 — Núcleo administrativo

`api` + `web`. Es también lo que se le factura a William como fase 1 del panel.

- Auth, empresa, membresías y roles
- Clientes con propiedades
- Proyectos con estado y asignación
- Fotos con la escalera de visibilidad y el photo release
- Publicación al sitio

## Fase 2 — Campo

`mobile`. El frente que sostiene todo lo demás, porque sin captura en sitio no hay
contenido que publicar ni horas que reportar.

- Asistencia con geocerca y foto, con banderas y aprobación
- Captura de fotos offline con bandeja de salida y reintento
- Cuadrillas y asignación diaria
- Sincronización con resolución de conflictos

**Depende de nada más que del esquema.** Puede arrancar en paralelo con la fase 1.

## Fase 3 — Comercial

Reemplazo de QuickBooks. Ver [[../adr/0001-reemplazar-quickbooks/README|ADR-0001]].

- Catálogo de servicios con costo y margen
- Estimados con firma y aceptación
- Facturas, pagos y numeración por empresa
- Costo real por proyecto contra lo estimado

**Bloqueado por una conversación, no por código:** hablar con el contador de
William antes de construir facturación. Ver los pendientes en [[../DECISIONES]].

## Fase 4 — Cliente y reportes

- Portal por link, con cuenta opcional
- Actualizaciones aprobadas y visibilidad por proyecto
- Ofertas de servicios y registro de leads
- Timesheets para el contador y acceso de solo lectura

## Fase 5 — Publicidad completa

- Pares antes/después como pieza propia
- Feed consultable para producción de redes
- Reseñas enganchadas al proyecto que las originó

## Descartado

Ideas que ya se evaluaron y no entran. Reabrirlas requiere una razón nueva, no
insistencia.

| Idea | Por qué no |
|---|---|
| Cálculo de nómina | Compliance de retenciones y estado. El contador lo hace. Ver [[vision#Qué NO somos]] |
| GPS continuo / rutas | Legal, confianza del trabajador, y no resuelve un dolor declarado |
| Inventario y compras | Categoría de Procore. No se compite ahí |
| Cobro con tarjeta en v1 | Se registra el pago; Stripe cuando aparezca la necesidad |
| PWA en vez de Flutter nativo | Las cuentas de App Store y Play ya están pagadas, y salir del stack conocido sale más caro en tiempo |

## Cómo entra algo nuevo acá

`/scope-check <idea>` la contrasta contra [[vision]]. Si pasa, `/spec-new` la
convierte en spec con su `goal`.
