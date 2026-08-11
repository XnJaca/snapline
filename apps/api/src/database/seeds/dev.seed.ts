import 'reflect-metadata';
import { DataSource } from 'typeorm';
import dataSource from '../../config/datasource';
import { newId } from '../../common/entities/base.entity';
import { AuthService } from '../../auth/auth.service';

/**
 * Devuelve el id de la fila que ya está, o la crea.
 *
 * El seed corre muchas veces sobre la misma base —después de una migración, al
 * volver a un branch—, así que insertar a ciegas lo vuelve inservible: falla en
 * la primera fila y no llega a las demás.
 *
 * Busca por **clave natural** y no por id, porque el id se genera en cada
 * corrida y nunca coincidiría con el de la vez anterior.
 */
async function obtenerOCrear(
  ds: DataSource,
  tabla: string,
  buscarPor: string,
  claves: unknown[],
  insertar: (id: string) => Promise<unknown>,
): Promise<string> {
  const filas = (await ds.query(
    `SELECT id FROM ${tabla} WHERE ${buscarPor} LIMIT 1`,
    claves,
  )) as Array<{ id: string }>;
  if (filas[0]) return filas[0].id;

  const id = newId();
  await insertar(id);
  return id;
}

// Datos de desarrollo. Corre con el rol migrador, que bypassa RLS.
async function seed(): Promise<void> {
  const ds = await dataSource.initialize();
  const password = await AuthService.hashPassword('Snapline123!');

  const companyId = await obtenerOCrear(
    ds, 'company', 'public_site_slug = $1', ['pcdmv'],
    (id) => ds.query(
      `INSERT INTO company (id, name, legal_name, public_site_slug) VALUES ($1,$2,$3,$4)`,
      [id, 'Professional Construction LLC', 'Professional Construction LLC', 'pcdmv'],
    ),
  );

  const ownerId = await obtenerOCrear(
    ds, 'app_user', 'email = $1', ['william@pcdmv.com'],
    (id) => ds.query(
      `INSERT INTO app_user (id, email, password_hash, name, locale) VALUES ($1,$2,$3,$4,$5)`,
      [id, 'william@pcdmv.com', password, 'William Ferman', 'en'],
    ),
  );

  const workerId = await obtenerOCrear(
    ds, 'app_user', 'phone = $1', ['+15551234567'],
    (id) => ds.query(
      `INSERT INTO app_user (id, phone, password_hash, name, locale) VALUES ($1,$2,$3,$4,$5)`,
      [id, '+15551234567', password, 'Carlos Ramírez', 'es'],
    ),
  );

  const ownerMembershipId = await obtenerOCrear(
    ds, 'membership', 'company_id = $1 AND user_id = $2', [companyId, ownerId],
    (id) => ds.query(
      `INSERT INTO membership (id, company_id, user_id, role, status, pay_rate_cents, employment_type, joined_at)
       VALUES ($1,$2,$3,'OWNER','ACTIVE',6500,'W2',now())`,
      [id, companyId, ownerId],
    ),
  );

  const workerMembershipId = await obtenerOCrear(
    ds, 'membership', 'company_id = $1 AND user_id = $2', [companyId, workerId],
    (id) => ds.query(
      `INSERT INTO membership (id, company_id, user_id, role, status, pay_rate_cents, employment_type, joined_at)
       VALUES ($1,$2,$3,'WORKER','ACTIVE',3200,'W2',now())`,
      [id, companyId, workerId],
    ),
  );

  const customerId = await obtenerOCrear(
    ds, 'customer', 'company_id = $1 AND email = $2', [companyId, 'martinez@example.com'],
    (id) => ds.query(
      `INSERT INTO customer (id, company_id, display_name, email, phone, source)
       VALUES ($1,$2,'Martinez Residence','martinez@example.com','+15559876543','REFERRAL')`,
      [id, companyId],
    ),
  );

  const siteId = await obtenerOCrear(
    ds, 'site', `customer_id = $1 AND address->>'line1' = $2`, [customerId, '100 Main St'],
    (id) => ds.query(
      `INSERT INTO site (id, company_id, customer_id, address, lat, lng, geofence_radius_m)
       VALUES ($1,$2,$3,$4,39.290385,-76.612189,150)`,
      [id, companyId, customerId, JSON.stringify({ line1: '100 Main St', city: 'Baltimore', state: 'MD', postalCode: '21201', country: 'US' })],
    ),
  );

  // Una segunda propiedad **sin punto**, a propósito: es el estado de todo lo
  // cargado antes de SPEC-0007 y lo único que permite probar cómo se ve una
  // propiedad a la que todavía hay que ubicar.
  await obtenerOCrear(
    ds, 'site', `customer_id = $1 AND address->>'line1' = $2`, [customerId, '9800 Georgia Ave'],
    (id) => ds.query(
      `INSERT INTO site (id, company_id, customer_id, address) VALUES ($1,$2,$3,$4)`,
      [id, companyId, customerId, JSON.stringify({ line1: '9800 Georgia Ave', city: 'Silver Spring', state: 'MD', postalCode: '20902', country: 'US' })],
    ),
  );

  const foremanId = await obtenerOCrear(
    ds, 'app_user', 'phone = $1', ['+15557654321'],
    (id) => ds.query(
      `INSERT INTO app_user (id, phone, password_hash, name, locale) VALUES ($1,$2,$3,$4,$5)`,
      [id, '+15557654321', password, 'María López', 'es'],
    ),
  );

  const foremanMembershipId = await obtenerOCrear(
    ds, 'membership', 'company_id = $1 AND user_id = $2', [companyId, foremanId],
    (id) => ds.query(
      `INSERT INTO membership (id, company_id, user_id, role, status, pay_rate_cents, employment_type, joined_at)
       VALUES ($1,$2,$3,'FOREMAN','ACTIVE',4500,'W2',now())`,
      [id, companyId, foremanId],
    ),
  );

  const crewId = await obtenerOCrear(
    ds, 'crew', 'company_id = $1 AND name = $2', [companyId, 'Cuadrilla A'],
    (id) => ds.query(
      `INSERT INTO crew (id, company_id, name, foreman_membership_id, color)
       VALUES ($1,$2,'Cuadrilla A',$3,'#2563EB')`,
      [id, companyId, foremanMembershipId],
    ),
  );

  // La forewoman integra su propia cuadrilla: la ficha lo exige.
  for (const miembro of [foremanMembershipId, workerMembershipId]) {
    await obtenerOCrear(
      ds, 'crew_member', 'crew_id = $1 AND membership_id = $2', [crewId, miembro],
      (id) => ds.query(
        `INSERT INTO crew_member (id, company_id, crew_id, membership_id, from_date)
         VALUES ($1,$2,$3,$4,'2026-01-01')`,
        [id, companyId, crewId, miembro],
      ),
    );
  }

  const projectId = await obtenerOCrear(
    ds, 'project', 'company_id = $1 AND name = $2', [companyId, 'Techo Martinez'],
    (id) => ds.query(
      `INSERT INTO project (id, company_id, customer_id, site_id, name, service_type, status)
       VALUES ($1,$2,$3,$4,'Techo Martinez','roofing','IN_PROGRESS')`,
      [id, companyId, customerId, siteId],
    ),
  );

  const georgiaSiteId = (await ds.query(
    `SELECT id FROM site WHERE customer_id = $1 AND address->>'line1' = $2`,
    [customerId, '9800 Georgia Ave'],
  ) as Array<{ id: string }>)[0]?.id;
  if (georgiaSiteId) {
    await obtenerOCrear(
      ds, 'project', 'company_id = $1 AND name = $2', [companyId, 'Baño Martinez'],
      (id) => ds.query(
        `INSERT INTO project (id, company_id, customer_id, site_id, name, service_type, status)
         VALUES ($1,$2,$3,$4,'Baño Martinez','bathroom','IN_PROGRESS')`,
        [id, companyId, customerId, georgiaSiteId],
      ),
    );
  }

  // La cuadrilla asignada a la obra hoy: es lo que hace probable el marcaje,
  // el pull del foreman y la bandera de asignación.
  await obtenerOCrear(
    ds, 'project_assignment', 'project_id = $1 AND crew_id = $2 AND work_date = CURRENT_DATE', [projectId, crewId],
    (id) => ds.query(
      `INSERT INTO project_assignment (id, company_id, project_id, crew_id, work_date)
       VALUES ($1,$2,$3,$4,CURRENT_DATE)`,
      [id, companyId, projectId, crewId],
    ),
  );

  await obtenerOCrear(
    ds, 'service_item', 'company_id = $1 AND name = $2', [companyId, 'Reemplazo de teja asfáltica'],
    (id) => ds.query(
      `INSERT INTO service_item (id, company_id, name, unit, unit_price_cents, cost_cents, taxable)
       VALUES ($1,$2,'Reemplazo de teja asfáltica','SQFT',450,210,false)`,
      [id, companyId],
    ),
  );

  console.log(JSON.stringify({
    companyId, projectId, customerId, siteId,
    owner: { email: 'william@pcdmv.com', membershipId: ownerMembershipId },
    worker: { phone: '+15551234567', membershipId: workerMembershipId },
    foreman: { phone: '+15557654321', membershipId: foremanMembershipId },
    crewId,
    password: 'Snapline123!',
  }, null, 2));

  await ds.destroy();
}

seed().catch((e) => { console.error(e); process.exit(1); });
