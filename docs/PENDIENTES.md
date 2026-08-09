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

- [x] ~~**Specs retroactivos.**~~ Escritos el 2026-08-08: SPEC-0001 a 0006 en
      `docs/specs/web/`, con su `goal` y sus criterios marcados, y movidos a
      Implementado en el BOARD.

      Van marcados como **retroactivos** a propósito: son registro de lo que hay,
      no el proceso funcionando. De acá en adelante el spec va antes del código.

- [x] ~~**Limpieza real del EXIF.**~~ Hecho el 2026-08-08 con `sharp`:
      `POST /media/:id/strip-exif` baja el objeto, lo reescribe sin metadatos y lo
      vuelve a subir. **Pasar una foto a `PUBLIC` lo dispara solo**, así que no
      depende de acordarse. Verificado con una foto con GPS real: metadatos de 12 a
      0 y el bloque EXIF ausente del archivo en el bucket.

      La orientación se aplica **antes** de borrar el EXIF: sin eso, quitar los
      metadatos deja las fotos verticales acostadas.

- [x] ~~**Módulo `client-portal`.**~~ Hecho el 2026-08-08. Magic link con token
      hasheado (en la base nunca queda en claro), `GET /p/:token` anónimo con rate
      limit, y el default **STAGES** verificado: el cliente ve la etapa y nada más
      hasta que la empresa lo pase a PROGRESS.

      Salió un bug de fondo: **`runUnscoped()` no bypassaba RLS** — solo logueaba.
      El rol de runtime no puede saltársela, que es el punto del ADR-0006. Se
      renombró a `runWithoutTenant()` con la doc corregida, y el token se canjea
      por `client_access_by_token()`, tercera y última función SECURITY DEFINER.

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

- [x] ~~**Rate limit** en endpoints públicos y login.~~ Hecho el 2026-08-08 con
      `@nestjs/throttler`: 120 req/min general, y **8/min en lo que acepta
      credenciales sin autenticación previa** — login, refresh y el portal del
      cliente. Verificado: al cuarto intento contra `/p/:token` responde 429.

- [x] ~~**Tests e2e contra Postgres.**~~ Hecho el 2026-08-08: 21 tests en
      `apps/api/test/`, con `pnpm test:e2e`. Cubren lo que se venía verificando a
      mano con curl —aislamiento entre dos empresas reales, geocerca recalculada,
      tarifa congelada, snapshot de precios, idempotencia de pagos, token del
      portal hasheado— contra el Postgres real, porque los invariantes viven en
      triggers, índices parciales y RLS que un mock no ejercita.

      El seed usa el rol migrador aparte: sembrar con el rol de runtime falla por
      RLS, que es exactamente lo que debe pasar. Y limpiar exige desactivar a
      propósito el trigger que bloquea el borrado de horas.

## ⚪ Higiene

- [x] ~~**Commitear.**~~ Hecho el 2026-08-08: repo en
      github.com/XnJaca/snapline, **público por ahora**. Auditada toda la historia
      antes de publicar — sin `.env`, sin `brief.md`, sin llaves.

      **Pendiente de decisión:** `DECISIONES.md` quedó público con la estrategia
      de precios y la nota de no mencionarle a William la fase 1. Pasar el repo a
      privado no deshace la exposición: sirve para adelante, no para atrás.

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

- [x] ~~**ADR-0005 — librería de i18n para Angular.**~~ Aceptado el 2026-08-08:
      **Transloco**. Pesaron los catálogos JSON compartidos con Flutter y Astro, y
      el cambio de idioma sin recargar, porque el `locale` es por usuario dentro de
      una misma cuenta. Ya no bloquea `apps/web`.

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
