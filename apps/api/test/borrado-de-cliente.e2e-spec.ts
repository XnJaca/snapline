import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { adminDataSource, bootstrapE2E, cleanup, cleanupOrphans, Fixture, seedCompany } from './setup';

/**
 * El invariante de SPEC-0009 contra el Postgres real. Lo que importa acá no es
 * que el endpoint conteste 409, sino que **la base lo impida igual** aunque
 * nadie pase por el servicio: el borrado es suave y la clave foránea no atrapa
 * nada, así que si el trigger no está, no hay invariante.
 */
describe('borrado de cliente (e2e)', () => {
  let app: INestApplication;
  let admin: DataSource;
  let a: Fixture;
  let owner: string;

  const http = () => request(app.getHttpServer());
  const auth = () => ({ Authorization: `Bearer ${owner}` });

  /** Un cliente nuevo con su propiedad, por el mismo camino que usa el panel. */
  const nuevoCliente = async (nombre: string): Promise<string> => {
    const res = await http().post('/api/customers').set(auth()).send({
      displayName: nombre,
      site: { address: { line1: '1 Test St', city: 'Baltimore', state: 'MD', postalCode: '21201', country: 'US' } },
    }).expect(201);
    return res.body.id;
  };

  const sitiosVivos = async (customerId: string): Promise<number> => {
    const [row] = await admin.query<Array<{ n: string }>>(
      `SELECT count(*) AS n FROM site WHERE customer_id = $1 AND deleted_at IS NULL`, [customerId]);
    return Number(row.n);
  };

  /** Borra saltándose el servicio: es la única forma de probar el trigger. */
  const borrarDirecto = (customerId: string) =>
    admin.query(`UPDATE customer SET deleted_at = now() WHERE id = $1`, [customerId]);

  beforeAll(async () => {
    ({ app } = await bootstrapE2E());
    admin = await adminDataSource();
    await cleanupOrphans(admin);
    a = await seedCompany(admin, 'borrado');
    const res = await http().post('/api/auth/login')
      .send({ identifier: a.ownerEmail, password: a.password }).expect(200);
    owner = res.body.accessToken;
  });

  afterAll(async () => {
    await cleanup(admin, [a]);
    await admin.destroy();
    await app.close();
  });

  describe('un cliente sin historia se borra', () => {
    it('responde 204 y se lleva sus propiedades', async () => {
      const id = await nuevoCliente('Sin historia');
      expect(await sitiosVivos(id)).toBe(1);

      await http().delete(`/api/customers/${id}`).set(auth()).expect(204);

      await http().get(`/api/customers/${id}`).set(auth()).expect(404);
      expect(await sitiosVivos(id)).toBe(0);
    });

    it('la cascada también ocurre saltándose el servicio', async () => {
      const id = await nuevoCliente('Cascada directa');

      await borrarDirecto(id);

      expect(await sitiosVivos(id)).toBe(0);
    });

    it('sus propiedades dejan de ser alcanzables por la ruta del cliente', async () => {
      const id = await nuevoCliente('Direccion que no debe quedar');
      await http().delete(`/api/customers/${id}`).set(auth()).expect(204);

      // Antes devolvía la dirección de la casa indefinidamente.
      const res = await http().get(`/api/customers/${id}/sites`).set(auth());
      expect(res.body).toEqual([]);
    });
  });

  describe('un cliente con obras no se borra', () => {
    it('responde 409 CUSTOMER_HAS_HISTORY', async () => {
      const res = await http().delete(`/api/customers/${a.customerId}`).set(auth()).expect(409);

      expect(res.body.code).toBe('CUSTOMER_HAS_HISTORY');
    });

    it('y la base lo impide aunque nadie pase por el servicio', async () => {
      await expect(borrarDirecto(a.customerId)).rejects.toThrow();
    });

    // Cancelado no es lo mismo que borrado: las horas trabajadas siguen siendo
    // horas pagables.
    it('una obra terminada retiene igual que una en curso', async () => {
      await admin.query(`UPDATE project SET status = 'COMPLETED' WHERE id = $1`, [a.projectId]);

      const res = await http().delete(`/api/customers/${a.customerId}`).set(auth()).expect(409);
      expect(res.body.code).toBe('CUSTOMER_HAS_HISTORY');

      await admin.query(`UPDATE project SET status = 'IN_PROGRESS' WHERE id = $1`, [a.projectId]);
    });
  });

  describe('la línea la marca lo enviado, no lo que existe', () => {
    const documento = (tabla: string, customerId: string, status: string) =>
      admin.query(
        `INSERT INTO ${tabla} (id, company_id, customer_id, number, status, subtotal_cents, tax_cents, total_cents${tabla === 'invoice' ? ', balance_cents' : ''})
         VALUES (gen_random_uuid(), $1, $2, $3, $4, 1000, 0, 1000${tabla === 'invoice' ? ', 1000' : ''})`,
        [a.companyId, customerId, `${tabla.slice(0, 3).toUpperCase()}-${Date.now()}${Math.random()}`.slice(0, 20), status],
      );

    it('un estimado en DRAFT no retiene', async () => {
      const id = await nuevoCliente('Solo un borrador');
      await documento('estimate', id, 'DRAFT');

      await http().delete(`/api/customers/${id}`).set(auth()).expect(204);
    });

    it('un estimado enviado sí retiene', async () => {
      const id = await nuevoCliente('Con estimado enviado');
      await documento('estimate', id, 'SENT');

      const res = await http().delete(`/api/customers/${id}`).set(auth()).expect(409);
      expect(res.body.code).toBe('CUSTOMER_HAS_HISTORY');
    });

    // Anular no borra: la factura anulada es parte del registro.
    it('una factura anulada retiene', async () => {
      const id = await nuevoCliente('Con factura anulada');
      await documento('invoice', id, 'VOID');

      await http().delete(`/api/customers/${id}`).set(auth()).expect(409);
    });

    it('una factura en borrador no retiene', async () => {
      const id = await nuevoCliente('Con factura en borrador');
      await documento('invoice', id, 'DRAFT');

      await http().delete(`/api/customers/${id}`).set(auth()).expect(204);
    });
  });
});
