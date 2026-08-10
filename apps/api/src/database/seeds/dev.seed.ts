import 'reflect-metadata';
import dataSource from '../../config/datasource';
import { newId } from '../../common/entities/base.entity';
import { AuthService } from '../../auth/auth.service';

// Datos de desarrollo. Corre con el rol migrador, que bypassa RLS.
async function seed(): Promise<void> {
  const ds = await dataSource.initialize();
  const password = await AuthService.hashPassword('Snapline123!');

  const companyId = newId();
  const ownerId = newId();
  const workerId = newId();
  const ownerMembershipId = newId();
  const workerMembershipId = newId();
  const customerId = newId();
  const siteId = newId();
  const projectId = newId();

  await ds.query(
    `INSERT INTO company (id, name, legal_name, public_site_slug) VALUES ($1,$2,$3,$4)`,
    [companyId, 'Professional Construction LLC', 'Professional Construction LLC', 'pcdmv'],
  );
  await ds.query(
    `INSERT INTO app_user (id, email, password_hash, name, locale) VALUES ($1,$2,$3,$4,$5)`,
    [ownerId, 'william@pcdmv.com', password, 'William Ferman', 'en'],
  );
  await ds.query(
    `INSERT INTO app_user (id, phone, password_hash, name, locale) VALUES ($1,$2,$3,$4,$5)`,
    [workerId, '+15551234567', password, 'Carlos Ramírez', 'es'],
  );
  await ds.query(
    `INSERT INTO membership (id, company_id, user_id, role, status, pay_rate_cents, employment_type, joined_at)
     VALUES ($1,$2,$3,'OWNER','ACTIVE',6500,'W2',now())`,
    [ownerMembershipId, companyId, ownerId],
  );
  await ds.query(
    `INSERT INTO membership (id, company_id, user_id, role, status, pay_rate_cents, employment_type, joined_at)
     VALUES ($1,$2,$3,'WORKER','ACTIVE',3200,'W2',now())`,
    [workerMembershipId, companyId, workerId],
  );
  await ds.query(
    `INSERT INTO customer (id, company_id, display_name, email, phone, source)
     VALUES ($1,$2,'Martinez Residence','martinez@example.com','+15559876543','REFERRAL')`,
    [customerId, companyId],
  );
  await ds.query(
    `INSERT INTO site (id, company_id, customer_id, address, lat, lng, geofence_radius_m)
     VALUES ($1,$2,$3,$4,39.290385,-76.612189,150)`,
    [siteId, companyId, customerId, JSON.stringify({ line1: '100 Main St', city: 'Baltimore', state: 'MD', postalCode: '21201', country: 'US' })],
  );
  await ds.query(
    `INSERT INTO project (id, company_id, customer_id, site_id, name, service_type, status)
     VALUES ($1,$2,$3,$4,'Techo Martinez','roofing','IN_PROGRESS')`,
    [projectId, companyId, customerId, siteId],
  );
  await ds.query(
    `INSERT INTO service_item (id, company_id, name, unit, unit_price_cents, cost_cents, taxable)
     VALUES ($1,$2,'Reemplazo de teja asfáltica','SQFT',450,210,false)`,
    [newId(), companyId],
  );

  console.log(JSON.stringify({
    companyId, projectId, customerId, siteId,
    owner: { email: 'william@pcdmv.com', membershipId: ownerMembershipId },
    worker: { phone: '+15551234567', membershipId: workerMembershipId },
    password: 'Snapline123!',
  }, null, 2));

  await ds.destroy();
}

seed().catch((e) => { console.error(e); process.exit(1); });
