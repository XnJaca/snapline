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
  let ds: DataSource;
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
    ({ app, ds } = await bootstrapE2E());
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

    it('aprobar congela la tarifa', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/time-entries/${entryId}/approve`).set('Authorization', `Bearer ${ownerA}`)
        .send({ reason: 'ok' }).expect(200);

      expect(res.body.status).toBe('APPROVED');
      expect(res.body.payRateCentsSnapshot).toBe(3200);
    });

    it('subir la tarifa después no recalcula lo ya aprobado', async () => {
      await admin.query(`UPDATE membership SET pay_rate_cents = 9999 WHERE company_id = $1 AND role = 'WORKER'`,
        [a.companyId]);

      const res = await request(app.getHttpServer())
        .get(`/api/time-entries/${entryId}`).set('Authorization', `Bearer ${ownerA}`).expect(200);

      expect(res.body.payRateCentsSnapshot).toBe(3200);
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
  });
});
