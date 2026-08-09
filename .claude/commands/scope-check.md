---
name: scope-check
description: Verifica si una idea entra en el alcance vigente de Snapline
allowed-tools: Read, Glob, Grep
---

Verificá si esta idea entra en el alcance de Snapline.

Idea recibida: $ARGUMENTS

## Pasos

1. Leé `docs/product/vision.md`, en especial **"Qué NO somos"** y **"La tesis"**.
2. Leé `docs/product/roadmap.md`, incluida la tabla de **descartados**: si la idea ya se evaluó y no entró, reabrirla necesita una razón nueva, no insistencia.
3. Revisá si ya hay un spec que la cubra (`docs/specs/`).

## Respondé exactamente esto

- **Veredicto**: entra / no entra / entra recortada
- **Contra qué**: la línea concreta de `product/vision.md` que la admite o la excluye
- **Frente**: cuál de los cinco, si entra
- **Qué la haría entrar**: si no entra, qué tendría que cambiar en la propuesta

## Los dos filtros que mandan

1. **¿Se puede usar sin entrenamiento?** Si la feature necesita explicación, choca
   con la tesis del producto. William ya paga QuickBooks y no lo usa por eso.
2. **¿Alimenta el ciclo o lo distrae?** El ciclo es: foto en sitio → aprobación →
   publicación → contenido de redes → leads. Lo que no lo alimente ni lo sostenga
   necesita una razón fuerte.

Sé directo. Si no entra, decilo en una línea y explicá por qué. No busques la
manera de que entre.
