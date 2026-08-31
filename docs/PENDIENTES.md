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

## 🔴 Antes de desplegar

Ninguno bloquea el prototipo: el recorrido corre completo en desarrollo.

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

- [x] ~~**Endpoint de sincronización para el móvil.**~~ Hecho el 2026-08-08.
      `POST /api/sync` sube la bandeja entera en una llamada y `GET /api/sync?since=`
      trae solo lo cambiado.

      Cuatro decisiones que importan: **cada operación va en su propia transacción**
      —una que falle no tira abajo las 39 que entraron—, se ordenan por `occurredAt`
      porque una salida no puede aplicarse antes que su entrada, **reintentar
      devuelve `duplicate` en vez de error** aprovechando que los ids los genera el
      dispositivo, y cada payload se valida contra su DTO: sin eso el lote entraba
      sin la validación que sí tienen los endpoints sueltos.

      El cursor lo da el servidor, no el reloj del dispositivo. Un WORKER solo
      sincroniza sus proyectos asignados.

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

- [ ] **CORS en el bucket de Backblaze — cuando el panel suba su primera foto.**
      Subir desde el navegador a una URL firmada dispara un preflight; sin reglas
      de CORS el browser corta la subida antes de que salga del cliente, y el
      error no dice CORS de forma obvia.

      > **El trigger se corrigió el 2026-08-30.** Decía *"solo cuando arranque
      > `apps/web`"*, y arrancar la app no es el momento: SPEC-0007 y SPEC-0008 no
      > suben nada. Lo que lo dispara es la primera pantalla que mande un archivo
      > al bucket desde el navegador, que todavía no tiene spec.

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
