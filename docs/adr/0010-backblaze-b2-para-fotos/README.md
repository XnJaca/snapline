---
id: ADR-0010
title: "Backblaze B2 para el almacenamiento de fotos"
aliases:
  - "ADR-0010: Backblaze B2 para el almacenamiento de fotos"
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

# ADR-0010: Backblaze B2 para el almacenamiento de fotos

> Reemplaza la decisión de **Cloudflare R2** que estaba en `DECISIONES.md` del
> 2026-08-07. Esa entrada queda tachada allá con su fecha.

## Contexto

Este producto es, en volumen, una app de fotos: cada obra genera decenas, y cada
una se sirve muchas veces —en la app, en el portal del cliente, en el sitio
público y en el material de redes.

La decisión original fue R2 con un argumento de una línea: **egreso sin cobro**.
Es un buen argumento, pero el almacenamiento en sí es más caro, y con miles de
proyectos acumulados el costo se corre de "servir" a "guardar".

## Decisión

**Backblaze B2**, vía su API compatible con S3.

El acceso va por `@aws-sdk/client-s3` apuntado al endpoint de B2. El código no
tiene nada específico de B2: cambiar de proveedor es cambiar tres variables de
entorno.

## Alternativas consideradas

### Alternativa A — Cloudflare R2

Egreso sin cobro, que es el argumento fuerte para servir imágenes.

**Por qué no:** el almacenamiento por TB es varias veces más caro. En este producto
el archivo histórico crece para siempre —las fotos de una obra terminada siguen
siendo el portafolio— mientras que el tráfico es acotado: un contratista con veinte
clientes no genera volumen de CDN.

### Alternativa B — S3

**Por qué no:** el peor de los dos mundos para este caso. Ya estaba descartado.

## Consecuencias

### Positivas

- Costo de almacenamiento sustancialmente menor, que es la partida que crece.
- API compatible con S3: el SDK, las URL firmadas y la subida por partes son los
  mismos que con cualquier otro proveedor.
- Sin dependencia de un solo proveedor: migrar es reconfigurar, no reescribir.

### Negativas / Costos

- **El egreso deja de ser gratis**, que era la razón original de elegir R2. Si el
  sitio público llega a tener tráfico real, esa partida aparece.
- Menos integrado con el resto del stack si algún día se usa Cloudflare para el
  sitio.

### Riesgos

- **Costo de egreso si el portafolio público crece.** Mitigación: poner un CDN
  delante del bucket. B2 tiene acuerdo con Cloudflare para no cobrar el tráfico
  hacia su CDN, así que esa es la salida natural si aparece el problema.
  **No se implementa hoy** — se registra como deuda con trigger: "cuando el sitio
  público pase de X visitas al mes".
- **Confirmar los números vigentes de precio** antes de comprometer una cifra con
  William. La comparación de arriba es cualitativa a propósito.

## Reglas que no cambian

Las de seguridad se mantienen tal cual, y no dependen del proveedor:

- **El bucket no es público.** Todo se sirve con URL firmada y de vida corta.
  Un bucket público pone las fotos de la casa de un cliente en internet abierto
  para quien adivine la ruta.
- **El EXIF se limpia antes de publicar.** Las fotos llevan coordenadas GPS.
- **Tipo y tamaño se validan en el servidor**, no solo en el cliente.

## Impacto en el modelo

- [[../../domain/contenido|contenido]] — `storage_key`, `upload_status`, `checksum`

## Referencias

- `apps/api/src/storage/`
- Decisión original: [[../../DECISIONES]], sección Arquitectura
