import { randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { adminDataSource, bootstrapE2E, cleanup, cleanupOrphans, Fixture, seedCompany } from './setup';

/**
 * Los invariantes del dominio, contra el Postgres real.
 *
 * Todo esto se venía verificando a mano con curl, que se evapora. Si alguno
 * empieza a pasar cuando debería fallar, se rompió una regla dura del CLAUDE.md.
 */
describe('invariantes del dominio (e2e)', () => {
  let app: INestApplication;
  let admin: DataSource;
  let http: ReturnType<typeof request>;
  let a: Fixture;
  let b: Fixture;
  let ownerA: string;
  let workerA: string;

  const login = async (identifier: string, password: string): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/login').send({ identifier, password }).expect(200);
    return res.body.accessToken;
  };

  beforeAll(async () => {
    ({ app } = await bootstrapE2E());
    http = request(app.getHttpServer());
    admin = await adminDataSource();
    await cleanupOrphans(admin);
    a = await seedCompany(admin, 'a');
    b = await seedCompany(admin, 'b');
    ownerA = await login(a.ownerEmail, a.password);
    workerA = await login(a.workerPhone, a.password);
  });

  afterAll(async () => {
    await cleanup(admin, [a, b]);
    await admin.destroy();
    await app.close();
  });

  // ------------------------------------------------------ aislamiento

  describe('aislamiento entre empresas (RLS)', () => {
    it('el cliente de otra empresa no existe, ni buscándolo por su id exacto', async () => {
      await request(app.getHttpServer())
        .get(`/api/customers/${b.customerId}`)
        .set('Authorization', `Bearer ${ownerA}`)
        .expect(404);
    });

    it('la lista solo trae lo propio', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/projects').set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(res.body.every((p: { companyId: string }) => p.companyId === a.companyId)).toBe(true);
    });

    it('el WORKER solo ve proyectos donde tiene asignación', async () => {
      // Sin asignación no ve nada, aunque el proyecto exista en su empresa.
      const sinAsignar = await request(app.getHttpServer())
        .get('/api/projects').set('Authorization', `Bearer ${workerA}`).expect(200);
      expect(sinAsignar.body).toHaveLength(0);

      // Y pedirlo por id da 404, no 403: no se confirma que exista.
      await request(app.getHttpServer())
        .get(`/api/projects/${a.projectId}`).set('Authorization', `Bearer ${workerA}`)
        .expect(404);

      await request(app.getHttpServer())
        .post(`/api/projects/${a.projectId}/assignments`).set('Authorization', `Bearer ${ownerA}`)
        .send({ membershipId: a.workerMembershipId, workDate: '2026-08-08' })
        .expect(201);

      const conAsignacion = await request(app.getHttpServer())
        .get('/api/projects').set('Authorization', `Bearer ${workerA}`).expect(200);
      expect(conAsignacion.body).toHaveLength(1);
    });

    it('no se puede crear apuntando a un cliente de otra empresa', async () => {
      await request(app.getHttpServer())
        .post('/api/projects').set('Authorization', `Bearer ${ownerA}`)
        .send({ customerId: b.customerId, siteId: b.siteId, name: 'robado' })
        .expect(404);
    });
  });

  // ----------------------------------------------------------- permisos

  describe('default deny', () => {
    it('sin token no se pasa', async () => {
      const res = await http.get('/api/projects').expect(401);
      expect(res.body.code).toBe('TOKEN_MISSING');
    });

    it('el WORKER no puede escribir proyectos', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/projects').set('Authorization', `Bearer ${workerA}`)
        .send({ customerId: a.customerId, siteId: a.siteId, name: 'x' })
        .expect(403);
      expect(res.body.code).toBe('PERMISSION_DENIED');
    });
  });

  // ------------------------------------------------------------- horas

  describe('registro de tiempo', () => {
    let entryId: string;

    it('la geocerca la calcula el servidor y ignora lo que mande el dispositivo', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/time-entries/clock-in').set('Authorization', `Bearer ${workerA}`)
        .send({
          projectId: a.projectId,
          deviceRecordedAt: new Date().toISOString(),
          lat: 39.65, lng: -76.61,           // ~40 km
          clockInWithinGeofence: true,        // mentira del cliente
          isMockLocation: true,
        })
        .expect(201);

      expect(res.body.clockInWithinGeofence).toBe(false);
      expect(res.body.clockInDistanceM).toBeGreaterThan(30_000);
      expect(res.body.flags).toContain('OUTSIDE_GEOFENCE');
      expect(res.body.flags).toContain('MOCK_LOCATION');
      entryId = res.body.id;
    });

    it('no deja dos registros abiertos de la misma persona', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/time-entries/clock-in').set('Authorization', `Bearer ${workerA}`)
        .send({ projectId: a.projectId, deviceRecordedAt: new Date().toISOString() })
        .expect(409);
      expect(res.body.code).toBe('TIME_ENTRY_ALREADY_OPEN');
    });

    it('acota una fecha del dispositivo en el futuro', async () => {
      await request(app.getHttpServer())
        .post(`/api/time-entries/${entryId}/clock-out`).set('Authorization', `Bearer ${workerA}`)
        .send({ deviceRecordedAt: new Date(Date.now() + 3_600_000).toISOString() })
        .expect(200);

      const res = await request(app.getHttpServer())
        .post('/api/time-entries/clock-in').set('Authorization', `Bearer ${workerA}`)
        .send({ projectId: a.projectId, deviceRecordedAt: '2030-01-01T00:00:00Z' })
        .expect(201);

      expect(res.body.flags).toContain('TIMESTAMP_OUT_OF_RANGE');
      expect(new Date(res.body.clockInAt).getFullYear()).toBeLessThan(2030);

      // Cerrarlo: un registro abierto bloquea el siguiente clock-in y acopla
      // este bloque con los que vienen después.
      await request(app.getHttpServer())
        .post(`/api/time-entries/${res.body.id}/clock-out`).set('Authorization', `Bearer ${workerA}`)
        .send({ deviceRecordedAt: new Date().toISOString() }).expect(200);
    });

    it('nadie aprueba sus propias horas', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/time-entries/${entryId}/approve`).set('Authorization', `Bearer ${workerA}`)
        .send({});
      expect([403]).toContain(res.status);
    });

    /**
     * La tarifa congelada no baja al cliente con ningún rol: va con
     * `select: false` y `@ApiHideProperty()`, igual que la de la membresía. El
     * invariante se comprueba en la base, que es donde vive.
     */
    const tarifaCongelada = async (): Promise<number | null> => {
      const [fila] = await admin.query<Array<{ pay_rate_cents_snapshot: string | null }>>(
        `SELECT pay_rate_cents_snapshot FROM time_entry WHERE id = $1`, [entryId]);
      return fila.pay_rate_cents_snapshot === null ? null : Number(fila.pay_rate_cents_snapshot);
    };

    it('aprobar congela la tarifa', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/time-entries/${entryId}/approve`).set('Authorization', `Bearer ${ownerA}`)
        .send({ reason: 'ok' }).expect(200);

      expect(res.body.status).toBe('APPROVED');
      expect(await tarifaCongelada()).toBe(3200);
      // Y no aparece en la respuesta: es lo que gana esa persona.
      expect(res.body.payRateCentsSnapshot).toBeUndefined();
    });

    it('subir la tarifa después no recalcula lo ya aprobado', async () => {
      await admin.query(`UPDATE membership SET pay_rate_cents = 9999 WHERE company_id = $1 AND role = 'WORKER'`,
        [a.companyId]);

      await request(app.getHttpServer())
        .get(`/api/time-entries/${entryId}`).set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(await tarifaCongelada()).toBe(3200);
    });

    it('la base bloquea el borrado', async () => {
      await expect(admin.query(`DELETE FROM time_entry WHERE id = $1`, [entryId])).rejects.toThrow();
    });
  });

  // -------------------------------------------------------- comercial

  describe('estimados y facturas', () => {
    let estimateId: string;
    let invoiceId: string;

    it('la línea copia el precio del catálogo', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/estimates').set('Authorization', `Bearer ${ownerA}`)
        .send({ customerId: a.customerId, projectId: a.projectId,
                lines: [{ serviceItemId: a.serviceItemId, qty: 100 }] })
        .expect(201);

      expect(res.body.totalCents).toBe(45_000);
      expect(res.body.lines[0].unitPriceCentsSnapshot).toBe(450);
      estimateId = res.body.id;
    });

    it('cambiar el catálogo no reescribe el documento emitido', async () => {
      await request(app.getHttpServer())
        .patch(`/api/service-items/${a.serviceItemId}`).set('Authorization', `Bearer ${ownerA}`)
        .send({ unitPriceCents: 900 }).expect(200);

      const res = await request(app.getHttpServer())
        .get(`/api/estimates/${estimateId}`).set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(res.body.totalCents).toBe(45_000);
      expect(res.body.lines[0].unitPriceCentsSnapshot).toBe(450);
    });

    it('la numeración es por empresa y arranca en 1', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/estimates/${estimateId}/send`).set('Authorization', `Bearer ${ownerA}`).expect(200);
      expect(res.body.number).toBe('EST-00001');
    });

    it('un estimado aceptado se factura una sola vez', async () => {
      await request(app.getHttpServer())
        .post(`/api/estimates/${estimateId}/accept`).set('Authorization', `Bearer ${ownerA}`)
        .send({}).expect(200);

      const inv = await request(app.getHttpServer())
        .post(`/api/estimates/${estimateId}/invoice`).set('Authorization', `Bearer ${ownerA}`)
        .send({}).expect(201);
      invoiceId = inv.body.id;

      const dup = await request(app.getHttpServer())
        .post(`/api/estimates/${estimateId}/invoice`).set('Authorization', `Bearer ${ownerA}`)
        .send({}).expect(409);
      expect(dup.body.code).toBe('ESTIMATE_ALREADY_INVOICED');
    });

    it('un reintento con la misma idempotencyKey no cobra dos veces', async () => {
      await request(app.getHttpServer())
        .post(`/api/invoices/${invoiceId}/send`).set('Authorization', `Bearer ${ownerA}`).expect(200);

      const pago = { amountCents: 20_000, method: 'CHECK', receivedAt: new Date().toISOString(), idempotencyKey: 'k-1' };
      const uno = await request(app.getHttpServer())
        .post(`/api/invoices/${invoiceId}/payments`).set('Authorization', `Bearer ${ownerA}`)
        .send(pago).expect(201);
      const dos = await request(app.getHttpServer())
        .post(`/api/invoices/${invoiceId}/payments`).set('Authorization', `Bearer ${ownerA}`)
        .send(pago).expect(201);

      expect(uno.body.balanceCents).toBe(dos.body.balanceCents);
    });

    it('un pago mayor al saldo se rechaza', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/invoices/${invoiceId}/payments`).set('Authorization', `Bearer ${ownerA}`)
        .send({ amountCents: 99_999_999, method: 'CASH', receivedAt: new Date().toISOString() })
        .expect(400);
      expect(res.body.code).toBe('PAYMENT_EXCEEDS_BALANCE');
    });
  });

  // ------------------------------------------------------ sincronización

  describe('sincronización offline', () => {
    const uid = () => crypto.randomUUID();
    const hace = (min: number) => new Date(Date.now() - min * 60_000).toISOString();

    it('sube una jornada entera en una llamada, en el orden en que ocurrió', async () => {
      const entry = uid();
      const res = await request(app.getHttpServer())
        .post('/api/sync').set('Authorization', `Bearer ${workerA}`)
        .send({ operations: [
          // A propósito desordenadas: el servidor las ordena por occurredAt.
          { clientId: uid(), type: 'timeEntry.clockOut', targetId: entry, occurredAt: hace(10),
            payload: { lat: 39.2904, lng: -76.6122, breakMinutes: 30 } },
          { clientId: uid(), type: 'timeEntry.clockIn', targetId: entry, occurredAt: hace(480),
            payload: { projectId: a.projectId, lat: 39.2904, lng: -76.6122 } },
          { clientId: uid(), type: 'media.register', targetId: uid(), occurredAt: hace(300),
            payload: { projectId: a.projectId, kind: 'PHOTO', mime: 'image/jpeg', checksum: uid() } },
        ] })
        .expect(200);

      expect(res.body.failed).toBe(0);
      expect(res.body.results.every((r: { status: string }) => r.status === 'applied')).toBe(true);
    });

    it('reintentar el mismo lote no duplica nada', async () => {
      const entry = uid();
      const lote = { operations: [
        { clientId: uid(), type: 'timeEntry.clockIn', targetId: entry, occurredAt: hace(200),
          payload: { projectId: a.projectId } },
        { clientId: uid(), type: 'timeEntry.clockOut', targetId: entry, occurredAt: hace(20),
          payload: {} },
      ] };

      await request(app.getHttpServer())
        .post('/api/sync').set('Authorization', `Bearer ${workerA}`).send(lote).expect(200);
      const dos = await request(app.getHttpServer())
        .post('/api/sync').set('Authorization', `Bearer ${workerA}`).send(lote).expect(200);

      expect(dos.body.failed).toBe(0);
      expect(dos.body.results.every((r: { status: string }) => r.status === 'duplicate')).toBe(true);
    });

    it('una operación inválida no tira abajo el resto del lote', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/sync').set('Authorization', `Bearer ${workerA}`)
        .send({ operations: [
          { clientId: uid(), type: 'media.register', targetId: uid(), occurredAt: hace(5),
            payload: { projectId: a.projectId, kind: 'PHOTO', mime: 'image/jpeg', checksum: uid() } },
          { clientId: uid(), type: 'media.register', targetId: uid(), occurredAt: hace(4),
            payload: { projectId: a.projectId, kind: 'PHOTO' } },   // sin mime ni checksum
        ] })
        .expect(200);

      expect(res.body.failed).toBe(1);
      expect(res.body.results[0].status).toBe('applied');
      expect(res.body.results[1].code).toBe('VALIDATION_FAILED');
    });

    it('el pull con cursor solo trae lo nuevo', async () => {
      const uno = await request(app.getHttpServer())
        .get('/api/sync').set('Authorization', `Bearer ${ownerA}`).expect(200);
      expect(uno.body.serverTime).toBeDefined();

      const dos = await request(app.getHttpServer())
        .get(`/api/sync?since=${encodeURIComponent(uno.body.serverTime)}`)
        .set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(dos.body.customers).toHaveLength(0);
      expect(dos.body.timeEntries).toHaveLength(0);
    });
  });

  // ------------------------------------------------- portal del cliente

  describe('portal del cliente', () => {
    let token: string;

    it('el token no se guarda en claro', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/client-access').set('Authorization', `Bearer ${ownerA}`)
        .send({ customerId: a.customerId, projectId: a.projectId }).expect(201);
      token = res.body.token;

      const [row] = await admin.query(`SELECT token_hash FROM client_access WHERE id = $1`, [res.body.id]);
      expect(row.token_hash).not.toBe(token);
      expect(row.token_hash).toHaveLength(64);
    });

    it('en modo STAGES no revela avance', async () => {
      const res = await http.get(`/api/p/${token}`).expect(200);
      expect(res.body[0].visibilityMode).toBe('STAGES');
      expect(res.body[0].updates).toHaveLength(0);
      expect(res.body[0].photos).toHaveLength(0);
    });

    it('un token inventado no entra', async () => {
      const res = await http.get('/api/p/no-existe-este-token').expect(401);
      expect(res.body.code).toBe('TOKEN_INVALID');
    });
  });

  // ------------------------------------------------------ permisos de sync

  describe('sync autoriza por operación, no solo por endpoint', () => {
    const uuid = (): string => randomUUID();

    /**
     * El endpoint entra con `time.clock`, que el WORKER tiene. Sin autorizar por
     * operación, esto le dejaba crear clientes saltándose `customers.write`.
     */
    it('un WORKER no puede crear clientes por la puerta de sync', async () => {
      const clientId = uuid();
      const res = await http
        .post('/api/sync')
        .set('Authorization', `Bearer ${workerA}`)
        .send({
          operations: [{
            clientId,
            type: 'customer.create',
            targetId: uuid(),
            payload: { displayName: 'Colado' },
            occurredAt: new Date().toISOString(),
          }],
        })
        .expect(200);

      expect(res.body.results[0].status).toBe('failed');
      expect(res.body.results[0].code).toBe('FORBIDDEN');

      const [row] = await admin.query(
        `SELECT true AS existe FROM customer WHERE display_name = $1`, ['Colado']);
      expect(row).toBeUndefined();
    });

    it('lo que sí puede del mismo lote se aplica igual', async () => {
      const res = await http
        .post('/api/sync')
        .set('Authorization', `Bearer ${workerA}`)
        .send({
          operations: [
            {
              clientId: uuid(), type: 'customer.create', targetId: uuid(),
              payload: { displayName: 'Tampoco' }, occurredAt: '2026-08-09T10:00:00.000Z',
            },
            {
              clientId: uuid(), type: 'timeEntry.clockIn', targetId: uuid(),
              payload: { projectId: a.projectId }, occurredAt: '2026-08-09T10:01:00.000Z',
            },
          ],
        })
        .expect(200);

      expect(res.body.results[0].code).toBe('FORBIDDEN');
      expect(res.body.results[1].status).toBe('applied');
      expect(res.body.failed).toBe(1);
    });

    it('el OWNER sí puede, y repetir la misma operación no la aplica dos veces', async () => {
      const clientId = uuid();
      const operacion = {
        clientId,
        type: 'customer.update',
        targetId: a.customerId,
        payload: { displayName: 'Nombre corregido' },
        occurredAt: new Date().toISOString(),
      };

      const primera = await http.post('/api/sync')
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ operations: [operacion] }).expect(200);
      expect(primera.body.results[0].status).toBe('applied');

      // La red se cortó después de escribir y el dispositivo reintenta.
      const segunda = await http.post('/api/sync')
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ operations: [operacion] }).expect(200);
      expect(segunda.body.results[0].status).toBe('duplicate');

      const [row] = await admin.query(
        `SELECT count(*)::int AS n FROM sync_operation WHERE client_id = $1`, [clientId]);
      expect(row.n).toBe(1);
    });

    /**
     * El caso de todos los días: el cliente ya existe y arranca un trabajo en
     * otra dirección. Antes no había forma de encolar esto sin señal.
     */
    it('se puede agregar una propiedad a un cliente que ya existe', async () => {
      const siteId = uuid();
      const res = await http.post('/api/sync')
        .set('Authorization', `Bearer ${ownerA}`)
        .send({
          operations: [{
            clientId: uuid(),
            type: 'site.create',
            targetId: siteId,
            payload: {
              customerId: a.customerId,
              address: {
                line1: '89 Bel Pre Rd', city: 'Rockville',
                state: 'MD', postalCode: '20853',
              },
            },
            occurredAt: new Date().toISOString(),
          }],
        })
        .expect(200);

      expect(res.body.results[0].status).toBe('applied');

      const [row] = await admin.query(
        `SELECT customer_id FROM site WHERE id = $1`, [siteId]);
      expect(row.customer_id).toBe(a.customerId);
    });

    /**
     * El contrato promete `displayName`. Con `SELECT *` la respuesta traía
     * `display_name` y el cliente generado parseaba, no encontraba nada y no
     * fallaba: descartaba la sincronización entera en silencio.
     */
    it('el pull devuelve lo que el contrato promete, no las columnas crudas', async () => {
      const res = await http.get('/api/sync')
        .set('Authorization', `Bearer ${ownerA}`).expect(200);

      // Importa la forma de la clave, no el valor: otro caso de esta suite le
      // cambia el nombre a este mismo cliente.
      const cliente = res.body.customers.find((c: { id: string }) => c.id === a.customerId);
      expect(cliente).toBeDefined();
      expect(typeof cliente.displayName).toBe('string');
      expect(cliente).not.toHaveProperty('display_name');
      expect(cliente).not.toHaveProperty('company_id');

      const sitio = res.body.sites.find((x: { id: string }) => x.id === a.siteId);
      expect(sitio.address.postalCode).toBe('21201');
      expect(sitio.geofenceRadiusM).toBe(150);
    });

    it('las bajas de site y assignment también se propagan', async () => {
      await admin.query(`UPDATE site SET deleted_at = now(), updated_at = now() WHERE id = $1`,
        [a.siteId]);

      const res = await http.get('/api/sync')
        .set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(res.body.deleted.sites).toContain(a.siteId);
      expect(res.body.deleted).toHaveProperty('assignments');
      expect(res.body.sites.map((x: { id: string }) => x.id)).not.toContain(a.siteId);

      await admin.query(`UPDATE site SET deleted_at = NULL WHERE id = $1`, [a.siteId]);
    });
  });

  // ------------------------------------------------- fotos de la obra

  describe('etiquetas y escalera de visibilidad', () => {
    const uuid = (): string => randomUUID();
    let assetId: string;

    /** Registrar por la bandeja: no toca el bucket, así que no exige credenciales. */
    const registrar = async (): Promise<string> => {
      const id = uuid();
      await http.post('/api/sync').set('Authorization', `Bearer ${ownerA}`)
        .send({ operations: [{
          clientId: uuid(), type: 'media.register', targetId: id,
          occurredAt: new Date().toISOString(),
          payload: { projectId: a.projectId, kind: 'PHOTO', mime: 'image/jpeg', checksum: uuid() },
        }] })
        .expect(200);
      return id;
    };

    beforeAll(async () => { assetId = await registrar(); });

    it('etiquetar reemplaza el conjunto entero', async () => {
      await http.post(`/api/media/${assetId}/tags`)
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ tags: ['BEFORE', 'DETAIL'] }).expect(200);

      const res = await http.post(`/api/media/${assetId}/tags`)
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ tags: ['AFTER'] }).expect(200);

      expect(res.body.tags).toEqual(['AFTER']);
    });

    /**
     * La condición que el diseño de "etiquetas adentro del asset" deja
     * implícita: sin tocar la fila, el cambio no entra en el pull incremental y
     * la etiqueta puesta en un teléfono no llega al otro.
     */
    it('etiquetar toca el asset, así que entra en el pull incremental', async () => {
      const otro = await registrar();
      // Un segundo atrás y no `now()`: el pull filtra con `updated_at > desde`
      // estricto, y el reloj de Node tiene precisión de milisegundo. Con el
      // cursor pegado a la escritura, la fila cae justo en el borde y el test
      // falla una de cada tres veces. La aserción busca por id, así que una
      // ventana más ancha no afloja lo que comprueba.
      const antes = new Date(Date.now() - 1000).toISOString();

      await http.post(`/api/media/${otro}/tags`)
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ tags: ['PROBLEM'] }).expect(200);

      const res = await http.get(`/api/sync?since=${encodeURIComponent(antes)}`)
        .set('Authorization', `Bearer ${ownerA}`).expect(200);

      const asset = res.body.mediaAssets.find((m: { id: string }) => m.id === otro);
      expect(asset).toBeDefined();
      expect(asset.tags).toEqual(['PROBLEM']);
    });

    it('una etiqueta que no existe en el dominio se rechaza', async () => {
      await http.post(`/api/media/${assetId}/tags`)
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ tags: ['SELFIE'] }).expect(400);
    });

    it('el WORKER etiqueta: es parte de capturar', async () => {
      const suyo = await registrar();
      await http.post(`/api/media/${suyo}/tags`)
        .set('Authorization', `Bearer ${workerA}`)
        .send({ tags: ['DURING'] }).expect(200);
    });

    it('el WORKER no sube de nivel: eso es de oficina', async () => {
      await http.post(`/api/media/${assetId}/visibility`)
        .set('Authorization', `Bearer ${workerA}`)
        .send({ visibility: 'CLIENT' }).expect(403);
    });

    it('INTERNAL no salta a PUBLIC de una vez', async () => {
      const res = await http.post(`/api/media/${assetId}/visibility`)
        .set('Authorization', `Bearer ${ownerA}`)
        .send({ visibility: 'PUBLIC' }).expect(400);

      expect(res.body.code).toBe('VISIBILITY_SKIPS_STEP');
    });

    it('el WORKER no borra fotos: son la evidencia de la obra', async () => {
      const suyo = await registrar();
      await http.delete(`/api/media/${suyo}`)
        .set('Authorization', `Bearer ${workerA}`).expect(403);
    });

    it('borrar es suave y la baja viaja en el pull', async () => {
      const victima = await registrar();
      // Un segundo atrás y no `now()`: el pull filtra con `updated_at > desde`
      // estricto, y el reloj de Node tiene precisión de milisegundo. Con el
      // cursor pegado a la escritura, la fila cae justo en el borde y el test
      // falla una de cada tres veces. La aserción busca por id, así que una
      // ventana más ancha no afloja lo que comprueba.
      const antes = new Date(Date.now() - 1000).toISOString();

      await http.delete(`/api/media/${victima}`)
        .set('Authorization', `Bearer ${ownerA}`).expect(204);

      const res = await http.get(`/api/sync?since=${encodeURIComponent(antes)}`)
        .set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(res.body.deleted.mediaAssets).toContain(victima);
      expect(res.body.mediaAssets.map((m: { id: string }) => m.id))
        .not.toContain(victima);

      // La fila sigue: un borrado duro no se puede propagar a un teléfono que
      // estuvo sin señal (regla 20).
      const [fila] = await admin.query(
        `SELECT deleted_at FROM media_asset WHERE id = $1`, [victima]);
      expect(fila.deleted_at).not.toBeNull();
    });

    it('la foto de un marcaje no se puede borrar: es la evidencia', async () => {
      const foto = await registrar();
      // Se ata a un marcaje cualquiera de la empresa: lo que se prueba es la
      // negativa del endpoint, no cómo llegó a estar atada.
      const [marcaje] = await admin.query(
        `SELECT id FROM time_entry WHERE company_id = $1 LIMIT 1`, [a.companyId]);
      await admin.query(
        `UPDATE time_entry SET clock_in_photo_id = $1 WHERE id = $2`,
        [foto, marcaje.id]);

      const res = await http.delete(`/api/media/${foto}`)
        .set('Authorization', `Bearer ${ownerA}`).expect(409);
      expect(res.body.code).toBe('ASSET_IN_USE');

      await admin.query(
        `UPDATE time_entry SET clock_in_photo_id = NULL WHERE id = $1`, [marcaje.id]);
    });

    it('escalón por escalón sí, y bajar no se restringe', async () => {
      // Llegar a PUBLIC exige subida terminada y EXIF limpio. Lo segundo lo
      // resuelve el servicio llamando al bucket, que acá no está configurado:
      // se deja puesto para que el caso pruebe la escalera y no el storage.
      await admin.query(
        `UPDATE media_asset SET upload_status = 'READY', exif_stripped_at = now() WHERE id = $1`,
        [assetId]);

      const mover = (visibility: string) => http.post(`/api/media/${assetId}/visibility`)
        .set('Authorization', `Bearer ${ownerA}`).send({ visibility }).expect(200);

      await mover('CLIENT');
      await mover('PUBLIC');
      await mover('INTERNAL');
    });
  });
});
