import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { adminDataSource, bootstrapE2E, cleanup, cleanupOrphans, Fixture, seedCompany } from './setup';

/**
 * El arco completo de SPEC-0011 contra el Postgres real: dar de alta a alguien,
 * dictarle el código, que lo canjee, sumarlo a una cuadrilla y asignarla a una
 * obra. Lo que se prueba al final es lo único que importa —que el trabajador
 * abra la app y vea esa obra—, y eso pasa por RLS, por la función
 * `SECURITY DEFINER` del canje y por el filtro por asignación.
 */
describe('alta de gente y cuadrillas (e2e)', () => {
  let app: INestApplication;
  let admin: DataSource;
  let a: Fixture;
  let owner: string;

  const http = () => request(app.getHttpServer());
  const auth = () => ({ Authorization: `Bearer ${owner}` });

  const telefonoNuevo = () => `+1${String(Date.now()).slice(-9).padStart(10, '4')}`;

  const altaDe = async (nombre: string, phone: string, extra: Record<string, unknown> = {}) => {
    const res = await http().post('/api/memberships').set(auth())
      .send({ name: nombre, phone, role: 'WORKER', payRateCents: 2200, employmentType: 'W2', ...extra })
      .expect(201);
    return res.body as { id: string; userId: string; inviteCode: string; status: string };
  };

  const usuariosCreados: string[] = [];

  beforeAll(async () => {
    ({ app } = await bootstrapE2E());
    admin = await adminDataSource();
    await cleanupOrphans(admin);
    a = await seedCompany(admin, 'gente');
    const res = await http().post('/api/auth/login')
      .send({ identifier: a.ownerEmail, password: a.password }).expect(200);
    owner = res.body.accessToken;
  });

  afterAll(async () => {
    a.userIds.push(...usuariosCreados);
    await cleanup(admin, [a]);
    await admin.destroy();
    await app.close();
  });

  describe('el arco completo', () => {
    it('de alta a obra asignada, sin tocar la base a mano', async () => {
      const phone = telefonoNuevo();
      const alta = await altaDe('Carlos Ramírez', phone);
      usuariosCreados.push(alta.userId);

      expect(alta.status).toBe('INVITED');
      expect(alta.inviteCode).toMatch(/^\d{6}$/);

      // El código vive hasheado: la fila no permite reconstruirlo.
      const [fila] = await admin.query<Array<{ invite_code_hash: string }>>(
        `SELECT invite_code_hash FROM membership WHERE id = $1`, [alta.id]);
      expect(fila.invite_code_hash).not.toBe(alta.inviteCode);
      expect(fila.invite_code_hash.startsWith('$2')).toBe(true);

      // Invitado todavía no entra, aunque acierte una contraseña.
      await http().post('/api/auth/login')
        .send({ identifier: phone, password: 'Snapline123!' }).expect(401);

      const canje = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
      expect(canje.body.membership.role).toBe('WORKER');
      const trabajador = canje.body.accessToken as string;

      // Todavía sin asignación: la app no le muestra ninguna obra.
      const sinObra = await http().get('/api/projects')
        .set({ Authorization: `Bearer ${trabajador}` }).expect(200);
      expect(sinObra.body).toHaveLength(0);

      const crew = await http().post('/api/crews').set(auth())
        .send({ name: 'Cuadrilla A', color: '#0aa' }).expect(201);
      await http().post(`/api/crews/${crew.body.id}/members`).set(auth())
        .send({ membershipId: alta.id, fromDate: '2026-09-01' }).expect(201);

      const hoy = new Date().toISOString().slice(0, 10);
      const asignacion = await http().post(`/api/projects/${a.projectId}/assignments`).set(auth())
        .send({ crewId: crew.body.id, fromDate: hoy }).expect(201);

      const conObra = await http().get('/api/projects')
        .set({ Authorization: `Bearer ${trabajador}` }).expect(200);
      expect(conObra.body.map((p: { id: string }) => p.id)).toContain(a.projectId);

      // Cerrar la labor de la cuadrilla ahí saca la obra de su lista: la
      // asignación vigente es la que no terminó.
      const ayer = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
      await http().post(`/api/projects/${a.projectId}/assignments/${asignacion.body.id}/end`)
        .set(auth()).send({ toDate: ayer }).expect(400);
      await http().post(`/api/projects/${a.projectId}/assignments/${asignacion.body.id}/end`)
        .set(auth()).send({ toDate: hoy }).expect(200);
      const terminadaHoy = await http().get('/api/projects')
        .set({ Authorization: `Bearer ${trabajador}` }).expect(200);
      // Termina hoy: todavía la ve, porque hoy todavía trabaja ahí.
      expect(terminadaHoy.body.map((p: { id: string }) => p.id)).toContain(a.projectId);

      // Y quitarla del todo lo devuelve a no ver nada: la misma puerta, en reversa.
      await http().delete(`/api/projects/${a.projectId}/assignments/${asignacion.body.id}`)
        .set(auth()).expect(204);
      const otraVezSinObra = await http().get('/api/projects')
        .set({ Authorization: `Bearer ${trabajador}` }).expect(200);
      expect(otraVezSinObra.body).toHaveLength(0);
    });
  });

  describe('el pull después de asignar', () => {
    it('trae la obra aunque sea vieja: lo que cambió es el acceso', async () => {
      const phone = telefonoNuevo() + '13';
      const alta = await altaDe('Recién Asignado', phone);
      usuariosCreados.push(alta.userId);

      const canje = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
      const trabajador = canje.body.accessToken as string;

      // La obra del fixture se creó antes: su `updated_at` ya es viejo, que es
      // exactamente el caso que rompía —el delta la dejaba afuera y el teléfono
      // recibía la asignación sin la obra—.
      const cursor = (await http().get('/api/sync')
        .set({ Authorization: `Bearer ${trabajador}` }).expect(200))
        .body.serverTime as string;

      const crew = await http().post('/api/crews').set(auth())
        .send({ name: 'Cuadrilla del pull' }).expect(201);
      await http().post(`/api/crews/${crew.body.id}/members`).set(auth())
        .send({ membershipId: alta.id, fromDate: '2026-09-01' }).expect(201);
      await http().post(`/api/projects/${a.projectId}/assignments`).set(auth())
        .send({ crewId: crew.body.id, fromDate: '2026-09-01' }).expect(201);

      const pull = await http()
        .get(`/api/sync?since=${encodeURIComponent(cursor)}`)
        .set({ Authorization: `Bearer ${trabajador}` })
        .expect(200);

      expect(pull.body.assignments).toHaveLength(1);
      expect(pull.body.projects.map((p: { id: string }) => p.id)).toContain(a.projectId);
      // Y con la obra baja de qué cliente es y dónde queda: sin eso la pantalla
      // muestra una obra sin dirección.
      expect(pull.body.customers.map((c: { id: string }) => c.id)).toContain(a.customerId);
      expect(pull.body.sites.map((s: { id: string }) => s.id)).toContain(a.siteId);
    });
  });

  describe('el código', () => {
    it('es de un solo uso', async () => {
      const phone = telefonoNuevo() + '1';
      const alta = await altaDe('Un Solo Uso', phone);
      usuariosCreados.push(alta.userId);

      await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' }).expect(200);

      // El segundo canje con la misma contraseña degrada a login (regla 19)…
      await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' }).expect(200);

      // …pero el código ya no vale por sí solo.
      const res = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'otra-cosa-8' }).expect(401);
      expect(res.body.code).toBe('INVITE_CODE_INVALID');
    });

    it('verificar no lo consume: después se canjea igual', async () => {
      const phone = telefonoNuevo() + '11';
      const alta = await altaDe('Verificado', phone);
      usuariosCreados.push(alta.userId);

      // El paso previo a pedir la contraseña. Comprobarlo no puede gastar el
      // código, o la persona quedaría afuera entre una pantalla y la otra.
      const check = await http().post('/api/auth/invite/verify')
        .send({ identifier: phone, code: alta.inviteCode }).expect(200);
      expect(check.body.needsPassword).toBe(true);

      await http().post('/api/auth/invite/verify')
        .send({ identifier: phone, code: alta.inviteCode }).expect(200);

      await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
    });

    it('verificar mal sí gasta intento: no es un oráculo gratis', async () => {
      const phone = telefonoNuevo() + '12';
      const alta = await altaDe('Oráculo', phone);
      usuariosCreados.push(alta.userId);

      const errado = alta.inviteCode === '000000' ? '111111' : '000000';
      await http().post('/api/auth/invite/verify')
        .send({ identifier: phone, code: errado }).expect(401);

      const [fila] = await admin.query<Array<{ invite_attempts: number }>>(
        `SELECT invite_attempts FROM membership WHERE id = $1`, [alta.id]);
      expect(Number(fila.invite_attempts)).toBe(1);
    });

    it('un código equivocado incrementa el contador en la base', async () => {
      const phone = telefonoNuevo() + '2';
      const alta = await altaDe('Contador', phone);
      usuariosCreados.push(alta.userId);

      const errado = alta.inviteCode === '000000' ? '111111' : '000000';
      await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: errado, password: 'Snapline123!' }).expect(401);

      // Un UPDATE que no atraviesa RLS no falla, no escribe, y deja el bloqueo
      // por intentos en decorado. Por eso se comprueba leyendo la fila.
      const [fila] = await admin.query<Array<{ invite_attempts: number }>>(
        `SELECT invite_attempts FROM membership WHERE id = $1`, [alta.id]);
      expect(Number(fila.invite_attempts)).toBe(1);
    });

    it('regenerarlo lo invalida, resetea el contador y expulsa la sesión viva', async () => {
      const phone = telefonoNuevo() + '3';
      const alta = await altaDe('Regenerado', phone);
      usuariosCreados.push(alta.userId);

      const canje = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' }).expect(200);
      const refresh = canje.body.refreshToken as string;

      const nuevo = await http().post(`/api/memberships/${alta.id}/invite`).set(auth()).expect(200);
      expect(nuevo.body.inviteCode).not.toBe(alta.inviteCode);
      expect(nuevo.body.status).toBe('INVITED');

      const [fila] = await admin.query<Array<{ invite_attempts: number; password_hash: string | null }>>(
        `SELECT m.invite_attempts, u.password_hash
         FROM membership m JOIN app_user u ON u.id = m.user_id WHERE m.id = $1`, [alta.id]);
      expect(Number(fila.invite_attempts)).toBe(0);
      // Es su única membresía: la contraseña vuelve a nulo y la elige de nuevo.
      expect(fila.password_hash).toBeNull();

      await http().post('/api/auth/refresh').send({ refreshToken: refresh }).expect(401);
    });
  });

  describe('el alta', () => {
    it('rechaza a alguien que ya es parte de la empresa', async () => {
      const phone = telefonoNuevo() + '4';
      const alta = await altaDe('Duplicado', phone);
      usuariosCreados.push(alta.userId);

      const res = await http().post('/api/memberships').set(auth())
        .send({ name: 'Duplicado', phone, role: 'WORKER' }).expect(409);
      expect(res.body.code).toBe('CONTACT_ALREADY_MEMBER');
    });

    it('reactiva a quien se fue y volvió, sobre la misma membresía', async () => {
      const phone = telefonoNuevo() + '5';
      const alta = await altaDe('De Temporada', phone);
      usuariosCreados.push(alta.userId);

      await http().post(`/api/memberships/${alta.id}/deactivate`).set(auth()).expect(200);

      const vuelta = await http().post('/api/memberships').set(auth())
        .send({ name: 'De Temporada', phone, role: 'FOREMAN', payRateCents: 2800 }).expect(201);

      expect(vuelta.body.id).toBe(alta.id);
      expect(vuelta.body.role).toBe('FOREMAN');
      expect(vuelta.body.payRateCents).toBe(2800);
      expect(vuelta.body.inviteCode).toMatch(/^\d{6}$/);
    });

    it('corrige el nombre y el teléfono de alguien ya cargado', async () => {
      const phone = telefonoNuevo() + '7';
      const alta = await altaDe('Pedro Solis', phone);
      usuariosCreados.push(alta.userId);

      // Un teléfono mal tecleado deja a esa persona sin poder entrar nunca: si
      // no se puede corregir, la única salida sería borrarla y recrearla.
      const corregido = telefonoNuevo() + '8';
      const res = await http().patch(`/api/memberships/${alta.id}`).set(auth())
        .send({ name: 'Pedro Solís', phone: corregido }).expect(200);

      expect(res.body.name).toBe('Pedro Solís');
      expect(res.body.phone).toBe(corregido);

      // Y entra con el nuevo, que es el punto de haberlo corregido.
      await http().post('/api/auth/invite/redeem')
        .send({ identifier: corregido, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
    });

    it('no deja quedarse con el teléfono de otra persona', async () => {
      const phone = telefonoNuevo() + '9';
      const alta = await altaDe('Choque', phone);
      usuariosCreados.push(alta.userId);

      const res = await http().patch(`/api/memberships/${alta.id}`).set(auth())
        .send({ phone: a.workerPhone }).expect(409);
      expect(res.body.code).toBe('CONTACT_ALREADY_MEMBER');
    });

    it('no deja crear un segundo OWNER', async () => {
      const res = await http().post('/api/memberships').set(auth())
        .send({ name: 'Otro dueño', phone: telefonoNuevo() + '6', role: 'OWNER' }).expect(409);
      expect(res.body.code).toBe('OWNER_ALREADY_EXISTS');
    });
  });

  /**
   * `crews.read` incluye al capataz, así que el scope por rol **es** el control
   * de acceso: sin él, el REST le entrega lo que el pull ya le niega.
   */
  describe('lo que ve el capataz', () => {
    it('ve la suya y ninguna otra', async () => {
      const phone = telefonoNuevo() + '9';
      const alta = await altaDe('Capataz Con Cuadrilla', phone, { role: 'FOREMAN' });
      usuariosCreados.push(alta.userId);

      const canje = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
      const capataz = { Authorization: `Bearer ${canje.body.accessToken}` };

      const suya = await http().post('/api/crews').set(auth())
        .send({ name: 'La suya', foremanMembershipId: alta.id }).expect(201);
      const ajena = await http().post('/api/crews').set(auth())
        .send({ name: 'La ajena' }).expect(201);

      const lista = await http().get('/api/crews').set(capataz).expect(200);
      expect(lista.body.map((c: { id: string }) => c.id)).toEqual([suya.body.id]);

      // La ajena no es un 403: que exista es lo que no le toca saber.
      await http().get(`/api/crews/${ajena.body.id}`).set(capataz).expect(404);
      await http().get(`/api/crews/${ajena.body.id}/members`).set(capataz).expect(404);
      await http().get(`/api/crews/${ajena.body.id}/assignments`).set(capataz).expect(404);

      // Y el dueño sigue viendo las dos.
      const todas = await http().get('/api/crews').set(auth()).expect(200);
      const ids = todas.body.map((c: { id: string }) => c.id);
      expect(ids).toContain(suya.body.id);
      expect(ids).toContain(ajena.body.id);
    });

    it('también ve la que integra sin liderarla', async () => {
      const phone = telefonoNuevo() + '1';
      const alta = await altaDe('Capataz Integrante', phone, { role: 'FOREMAN' });
      usuariosCreados.push(alta.userId);

      const canje = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
      const capataz = { Authorization: `Bearer ${canje.body.accessToken}` };

      const crew = await http().post('/api/crews').set(auth())
        .send({ name: 'La que integra' }).expect(201);
      // Sin liderarla: entra como miembro, y la vigencia es de hoy.
      const hoy = new Date().toISOString().slice(0, 10);
      await http().post(`/api/crews/${crew.body.id}/members`).set(auth())
        .send({ membershipId: alta.id, fromDate: hoy }).expect(201);

      const lista = await http().get('/api/crews').set(capataz).expect(200);
      expect(lista.body.map((c: { id: string }) => c.id)).toEqual([crew.body.id]);
      await http().get(`/api/crews/${crew.body.id}/members`).set(capataz).expect(200);
    });
  });

  describe('el solape de cuadrillas', () => {
    it('dice con cuál choca, y lo dice como dato y no dentro de la frase', async () => {
      const phone = telefonoNuevo() + '8';
      const alta = await altaDe('Quien Se Repite', phone);
      usuariosCreados.push(alta.userId);

      const primera = await http().post('/api/crews').set(auth())
        .send({ name: 'Los de Rockville' }).expect(201);
      await http().post(`/api/crews/${primera.body.id}/members`).set(auth())
        .send({ membershipId: alta.id, fromDate: '2026-09-01' }).expect(201);

      const segunda = await http().post('/api/crews').set(auth())
        .send({ name: 'Los de Bethesda' }).expect(201);
      const choque = await http().post(`/api/crews/${segunda.body.id}/members`).set(auth())
        .send({ membershipId: alta.id, fromDate: '2026-09-15' }).expect(409);

      expect(choque.body.code).toBe('CREW_MEMBER_OVERLAP');
      // El nombre viaja aparte: el panel arma la frase en el idioma de quien
      // mira, y la del servidor es solo el respaldo.
      expect(choque.body.details).toEqual([{ field: 'crew', message: 'Los de Rockville' }]);
    });
  });

  /**
   * Poner, terminar y quitar cuelgan del mismo `crews.write`. Que los tres
   * decoradores digan lo mismo se ve leyendo; que sigan diciéndolo después de
   * que alguien toque uno solo, no.
   */
  describe('el permiso de asignar', () => {
    it('el capataz no pone, no termina y no quita', async () => {
      const phone = telefonoNuevo() + '7';
      const alta = await altaDe('Capataz Sin Permiso', phone, { role: 'FOREMAN' });
      usuariosCreados.push(alta.userId);

      const canje = await http().post('/api/auth/invite/redeem')
        .send({ identifier: phone, code: alta.inviteCode, password: 'Snapline123!' })
        .expect(200);
      const capataz = { Authorization: `Bearer ${canje.body.accessToken}` };

      const crew = await http().post('/api/crews').set(auth())
        .send({ name: 'Cuadrilla ajena' }).expect(201);
      const puesta = await http().post(`/api/projects/${a.projectId}/assignments`).set(auth())
        .send({ crewId: crew.body.id, fromDate: '2026-09-01' }).expect(201);

      const hoy = new Date().toISOString().slice(0, 10);
      await http().post(`/api/projects/${a.projectId}/assignments`).set(capataz)
        .send({ crewId: crew.body.id, fromDate: hoy }).expect(403);
      await http().post(`/api/projects/${a.projectId}/assignments/${puesta.body.id}/end`)
        .set(capataz).send({ toDate: hoy }).expect(403);
      await http().delete(`/api/projects/${a.projectId}/assignments/${puesta.body.id}`)
        .set(capataz).expect(403);

      // Y sigue viendo la obra: lo que se le niega es escribir, no mirar.
      await http().get('/api/projects').set(capataz).expect(200);
    });
  });

  describe('la tarifa', () => {
    it('sale por /memberships y por ninguna otra vía', async () => {
      const lista = await http().get('/api/memberships').set(auth()).expect(200);
      expect(lista.body.some((m: { payRateCents: number | null }) => m.payRateCents !== null)).toBe(true);

      // La misma membresía embebida en cuadrillas no la lleva: la ve el FOREMAN.
      const crew = await http().post('/api/crews').set(auth()).send({ name: 'Sin tarifas' }).expect(201);
      await http().post(`/api/crews/${crew.body.id}/members`).set(auth())
        .send({ membershipId: a.workerMembershipId, fromDate: '2026-09-01' }).expect(201);

      const miembros = await http().get(`/api/crews/${crew.body.id}/members`).set(auth()).expect(200);
      expect(miembros.body[0].name).toBe('Worker');
      expect(JSON.stringify(miembros.body)).not.toContain('payRate');
      // Ni el contacto de la persona, que es lo que DEBT-0010 proponía arrastrar.
      expect(JSON.stringify(miembros.body)).not.toContain(a.workerPhone);
    });
  });
});
