// Antes de importar la app: el origen de CORS se lee al levantarla, y el test no
// puede depender de un `.env` que en CI no existe.
process.env.WEB_ORIGIN = 'http://localhost:4200';
process.env.SESSION_COOKIE_SECURE = 'false';

import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { adminDataSource, bootstrapE2E, cleanup, cleanupOrphans, Fixture, seedCompany } from './setup';

/**
 * La sesión del panel contra el Postgres real (SPEC-0008). Lo que importa acá no
 * es que el login ande —eso ya se probaba— sino dónde viaja el refresh token y
 * qué pasa cuando se cierra sesión.
 */
describe('sesión del panel (e2e)', () => {
  let app: INestApplication;
  let admin: DataSource;
  let jwt: JwtService;
  let a: Fixture;

  const http = () => request(app.getHttpServer());
  const setCookie = (res: request.Response): string[] => {
    const raw = res.headers['set-cookie'];
    return Array.isArray(raw) ? raw : [raw as string];
  };
  const refreshCookieOf = (res: request.Response): string =>
    setCookie(res).find((c) => c.startsWith('sl_refresh='))!;
  const valueOf = (cookie: string): string => cookie.split(';')[0];

  const webLogin = () =>
    http().post('/api/auth/web/login').send({ identifier: a.ownerEmail, password: a.password });

  const tokenVersionOf = async (membershipId: string): Promise<number> => {
    const [row] = await admin.query<{ token_version: number }[]>(
      `SELECT token_version FROM membership WHERE id = $1`, [membershipId]);
    return row.token_version;
  };

  beforeAll(async () => {
    ({ app } = await bootstrapE2E());
    jwt = app.get(JwtService);
    admin = await adminDataSource();
    await cleanupOrphans(admin);
    a = await seedCompany(admin, 'sesion');
  });

  afterAll(async () => {
    await cleanup(admin, [a]);
    await admin.destroy();
    await app.close();
  });

  // -------------------------------------------------------------- la cookie

  describe('el refresh no está al alcance de JavaScript', () => {
    it('no viaja en el cuerpo de la respuesta', async () => {
      const res = await webLogin().expect(200);

      expect(res.body.refreshToken).toBeUndefined();
      expect(JSON.stringify(res.body)).not.toContain('refreshToken');
      expect(res.body.accessToken).toEqual(expect.any(String));
      expect(res.body.membership.permissions).toContain('projects.publish');
    });

    it('viaja en una cookie httpOnly con los atributos de ADR-0014', async () => {
      const cookie = refreshCookieOf(await webLogin().expect(200));

      expect(cookie).toContain('HttpOnly');
      expect(cookie).toContain('SameSite=Strict');
      expect(cookie).toContain('Path=/api/auth/web');
      expect(cookie).toContain('Max-Age=2592000');
    });

    it('entrar con teléfono da lo mismo que entrar con email', async () => {
      const res = await http().post('/api/auth/web/login')
        .send({ identifier: a.workerPhone, password: a.password }).expect(200);

      expect(res.body.refreshToken).toBeUndefined();
      expect(refreshCookieOf(res)).toContain('HttpOnly');
      // Un WORKER entra igual: el panel no cierra la puerta por rol.
      expect(res.body.membership.role).toBe('WORKER');
      expect(res.body.membership.permissions).not.toContain('billing.read');
    });

    it('el token_version no se acepta del cliente', async () => {
      const antes = await tokenVersionOf(a.ownerMembershipId);

      await http().post('/api/auth/web/login')
        .send({ identifier: a.ownerEmail, password: a.password, tokenVersion: 99, token_version: 99 })
        .expect(200);

      expect(await tokenVersionOf(a.ownerMembershipId)).toBe(antes);
    });
  });

  // ------------------------------------------------------------- recargar

  describe('recargar la página', () => {
    it('la cookie sola devuelve la sesión, con un access token nuevo', async () => {
      const login = await webLogin().expect(200);

      const res = await http().post('/api/auth/web/refresh')
        .set('Cookie', valueOf(refreshCookieOf(login))).expect(200);

      expect(res.body.refreshToken).toBeUndefined();
      expect(res.body.user.id).toBe(login.body.user.id);
      expect(res.body.accessToken).toEqual(expect.any(String));
    });

    it('sin cookie responde 401 TOKEN_INVALID, no 500', async () => {
      const res = await http().post('/api/auth/web/refresh').expect(401);

      expect(res.body.code).toBe('TOKEN_INVALID');
    });
  });

  // --------------------------------------------------------------- logout

  describe('cerrar sesión invalida de verdad', () => {
    it('sube el contador y la cookie vieja deja de servir', async () => {
      const login = await webLogin().expect(200);
      const cookie = valueOf(refreshCookieOf(login));
      const antes = await tokenVersionOf(a.ownerMembershipId);

      const out = await http().post('/api/auth/web/logout').set('Cookie', cookie).expect(204);

      expect(await tokenVersionOf(a.ownerMembershipId)).toBe(antes + 1);
      expect(refreshCookieOf(out)).toContain('Max-Age=0');

      // La firma sigue siendo válida y aun así no entra: es el punto del contador.
      const reusada = await http().post('/api/auth/web/refresh').set('Cookie', cookie).expect(401);
      expect(reusada.body.code).toBe('TOKEN_INVALID');
    });

    it('es idempotente: sin cookie, y dos veces seguidas, responde 204', async () => {
      const cookie = valueOf(refreshCookieOf(await webLogin().expect(200)));

      await http().post('/api/auth/web/logout').expect(204);
      await http().post('/api/auth/web/logout').set('Cookie', cookie).expect(204);
      await http().post('/api/auth/web/logout').set('Cookie', cookie).expect(204);
    });

    /**
     * El criterio que el `?? 0` hace posible. Un refresh emitido antes de que el
     * claim existiera no lo lleva: con igualdad estricta se caerían de golpe todas
     * las sesiones vivas del móvil el día del deploy.
     */
    it('un refresh emitido antes del deploy —sin el claim— sigue entrando', async () => {
      await admin.query(`UPDATE membership SET token_version = 0 WHERE id = $1`, [a.workerMembershipId]);

      const viejo = await jwt.signAsync(
        { sub: a.workerUserId, companyId: a.companyId, membershipId: a.workerMembershipId,
          role: 'WORKER', typ: 'refresh' },
        { expiresIn: '30d' },
      );
      expect(JSON.parse(Buffer.from(viejo.split('.')[1], 'base64url').toString()).tv).toBeUndefined();

      await http().post('/api/auth/web/refresh').set('Cookie', `sl_refresh=${viejo}`).expect(200);
      // Y el móvil, que manda el mismo token en el cuerpo, tampoco se cae.
      await http().post('/api/auth/refresh').send({ refreshToken: viejo }).expect(200);
    });
  });

  // ----------------------------------------------------------------- CORS

  describe('CORS con credenciales', () => {
    it('responde el origen configurado, nunca el comodín', async () => {
      const res = await http().options('/api/auth/web/login')
        .set('Origin', 'http://localhost:4200')
        .set('Access-Control-Request-Method', 'POST');

      expect(res.headers['access-control-allow-origin']).toBe('http://localhost:4200');
      expect(res.headers['access-control-allow-credentials']).toBe('true');
    });

    it('un origen distinto no recibe permiso', async () => {
      const res = await http().options('/api/auth/web/login')
        .set('Origin', 'https://falsificado.example')
        .set('Access-Control-Request-Method', 'POST');

      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });
  });
});
