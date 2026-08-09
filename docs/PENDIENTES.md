---
id: PENDIENTES
title: "Pendientes — qué falta hacer"
type: pendientes
updated: 2026-08-08
tags:
  - pendientes
---

# Pendientes

Lo que falta, ordenado por qué tan caro sale olvidarlo. Las decisiones de producto
y comerciales viven en [[DECISIONES]]; esto es ejecución.

Marcar con `[x]` al completar y borrar la línea cuando ya no aporte contexto.

---

## 🔴 Bloquean el prototipo

- [x] ~~**Crear el bucket de Backblaze de desarrollo.**~~ Hecho el 2026-08-08:
      `snapline-dev` privado en `us-east-005`, con llave acotada a ese bucket.

- [x] ~~**Probar la subida real de punta a punta.**~~ Verificado el 2026-08-08:
      registrar → PUT firmado (200) → `uploaded` → descarga firmada (200), archivo
      idéntico byte a byte. Sin firma el bucket responde `401 UnauthorizedAccess`,
      así que la afirmación de "bucket privado" está comprobada y no supuesta.

- [ ] **Bucket de producción aparte, con su propia application key.** Nunca la
      misma llave que desarrollo: una demo no debe poder escribir sobre las fotos
      reales de un cliente.

      **1. Crear el bucket** (B2 Cloud Storage → Create a Bucket):

      | Campo | Valor | Por qué |
      |---|---|---|
      | Bucket Unique Name | `snapline-prod` | **Con guion, nunca guion bajo** |
      | Files in Bucket are | **Private** | ADR-0010: todo se sirve con URL firmada |
      | Default Encryption | **Enable** (SSE-B2) | Gratis y transparente para el API de S3 |
      | Object Lock | Disable | Vuelve los archivos inmutables y complica el borrado |

      > **El guion bajo rompe.** B2 solo acepta letras, números y `-`, y aunque los
      > aceptara, el cliente arma la URL como `bucket.s3.<region>.backblazeb2.com`:
      > un guion bajo no es válido en DNS y el certificado TLS no haría match. El
      > nombre es único **entre todas las cuentas de B2**.

      **2. Application key** (Account → Application Keys):
      **alcance solo ese bucket**, no "All"; Read and Write; sin *Duration* — un
      vencimiento hace que las subidas empiecen a fallar con 403 sin que nada avise.
      **La `applicationKey` se muestra una sola vez.**

      **3. La región se copia del endpoint que muestra el bucket, no se adivina.**

      > Ya mordió una vez: con la región equivocada Backblaze responde
      > `InvalidAccessKeyId — the key is not valid`, que suena a llave mal copiada y
      > en realidad es región mal puesta. Esta cuenta está en **`us-east-005`**.
      > Para diagnosticarlo, un `HeadBucket` contra cada región dice cuál la acepta.

      **4. Variables** (`STORAGE_ENDPOINT`, `STORAGE_REGION`, `STORAGE_BUCKET`,
      `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`) — ver `.env.example`.

- [ ] **La cuenta de Backblaze es compartida con ACDEMIC.** El bucket
      `acdemic-attachments` vive en la misma cuenta: la facturación se mezcla y el
      radio de daño de cualquier credencial cruza los dos productos. Revisar antes
      de producción si conviene separar cuentas.

- [ ] **`JWT_SECRET` propio para producción.** El de desarrollo ya es aleatorio
      (se generó el 2026-08-08), pero producción necesita el suyo y **nunca el
      mismo**: `openssl rand -base64 48`.

- [x] ~~**Probar una subida real de punta a punta.**~~ Verificado el 2026-08-08:
      registrar → PUT firmado (200) → `uploaded` → descarga firmada (200), archivo
      idéntico byte a byte. Sin firma el bucket responde `401 UnauthorizedAccess`.

## 🟠 Antes de que crezca la superficie

- [x] ~~**Envelope canónico de errores.**~~ Hecho el 2026-08-08, ADR-0011.
      `{statusCode, code, message, details[], path, timestamp}` en toda respuesta de
      error. **`code` es estable y no se traduce** — es contra lo que ramifica el
      cliente, porque `message` sí se va a traducir (regla 24). 30 códigos en el
      enum, y viajan al contrato: el cliente los recibe tipados.

      Dos cosas que arregla y no eran obvias: `message` ya nunca cambia de tipo
      (la validación va a `details`), y **un invariante que salta en la base llega
      con el mismo código que si lo hubiera atajado el servicio** — el filtro mapea
      triggers e índices. Ojo: los índices traen su nombre en el mensaje, los
      triggers solo el texto del `RAISE`.

- [ ] **Specs retroactivos de `catalog`, `crews`, `billing`, `reports` y
      `publishing`.** Se construyeron sin spec, contra la regla 2. O se escriben
      con `/spec-new`, o se registra la deuda con `/debt-new` — pero no queda así.

- [x] ~~**Limpieza real del EXIF.**~~ Hecho el 2026-08-08 con `sharp`:
      `POST /media/:id/strip-exif` baja el objeto, lo reescribe sin metadatos y lo
      vuelve a subir. **Pasar una foto a `PUBLIC` lo dispara solo**, así que no
      depende de acordarse. Verificado con una foto con GPS real: metadatos de 12 a
      0 y el bloque EXIF ausente del archivo en el bucket.

      La orientación se aplica **antes** de borrar el EXIF: sin eso, quitar los
      metadatos deja las fotos verticales acostadas.

- [ ] **Módulo `client-portal`.** Tablas y entities listas, sin controller.
      Necesita definir la vía de auth por token público (magic link), que toca el
      `AuthGuard`. Ver ADR-0004.

## 🟡 Cuando corresponda

- [ ] **Confirmar el tratamiento de sales tax en Maryland** con el contador de
      William. Hoy la tasa es configurable y está en cero. Ver ADR-0001.

- [ ] **Hablar con el contador antes de que salga la primera factura real.**
      Si no acepta los datos, el módulo no sirve por impecable que esté.

- [ ] **CDN delante del bucket** si el sitio público agarra tráfico. B2 cobra
      egreso; hacia la CDN de Cloudflare no. **Trigger:** cuando el portafolio
      público pase de ~10k visitas al mes. Ver ADR-0010.

- [ ] **Cobro con tarjeta.** Hoy solo se registra el pago recibido. Fuera de
      alcance a propósito — ver "Qué NO somos" en [[product/vision]].

- [ ] **Rate limit** en los endpoints públicos y en login. Hoy no hay ninguno.

- [ ] **Tests e2e contra Postgres.** Los 15 actuales son unitarios y de
      arquitectura. Los invariantes de base (RLS, triggers, numeración) se
      probaron a mano y esa verificación no quedó automatizada.

## ⚪ Higiene

- [ ] **Commitear.** Al 2026-08-08 el repo no tiene un solo commit y todo está sin
      trackear. Es el riesgo más tonto de la lista.

- [ ] **`apps/web` y `apps/site`** sin scaffold. Al crearlas, agregarlas a
      `pnpm-workspace.yaml` — hoy solo lista `apps/api` y `packages/*`.

- [ ] **CORS en el bucket de Backblaze — solo cuando arranque `apps/web`.**
      Subir desde el navegador a una URL firmada dispara un preflight; sin reglas
      de CORS el browser corta la subida antes de que salga del cliente, y el
      error no dice CORS de forma obvia.

      **Desde Flutter nativo no aplica** — no hay CORS fuera del navegador, por eso
      el prototipo no lo necesita.

      En B2: Bucket Settings → CORS Rules, permitiendo `PUT` y `GET` desde el
      origen del admin, con `content-type` entre los headers permitidos (el cliente
      lo manda firmado). En desarrollo el origen es `http://localhost:4200`; en
      producción, el dominio real. **Nunca `*` en producción.**

- [ ] **ADR-0005 (librería de i18n para Angular)** sigue en `propuesto`.
      Bloquea el primer componente de `apps/web`.

- [ ] **Verificar el nombre** en App Store Connect, Google Play y USPTO antes de
      registrar bundle ID o dominio. Ver [[NOMBRE]].

---

## Cómo se mantiene

Este archivo es para lo que **no** tiene lugar en otro lado. Si algo encaja en una
categoría existente, va ahí y no acá:

| Si es… | Va a |
|---|---|
| Una feature | `/spec-new` → `docs/specs/` |
| Deuda técnica con trigger | `/debt-new` → `docs/tech-debt/` |
| Una decisión que cuesta revertir | `/adr-new` → `docs/adr/` |
| Un pendiente comercial o de relación | [[DECISIONES]] |
