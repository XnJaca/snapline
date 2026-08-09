import 'reflect-metadata';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import { initializeTransactionalContext } from 'typeorm-transactional';
import { AppModule } from '../src/app.module';
import { HttpExceptionFilter } from '../src/common/errors/http-exception.filter';
import { newId } from '../src/common/entities/base.entity';
import { AuthService } from '../src/auth/auth.service';

export interface Fixture {
  companyId: string;
  userIds: string[];
  ownerEmail: string;
  workerPhone: string;
  password: string;
  customerId: string;
  siteId: string;
  projectId: string;
  serviceItemId: string;
  workerMembershipId: string;
}

/**
 * Corre contra el Postgres real: los invariantes que importan viven en la base
 * (triggers, índices parciales, RLS) y un mock no los ejercita.
 */
/**
 * Conexión aparte con el rol migrador. El DataSource de la app usa el rol de
 * runtime, al que RLS sí le aplica: sembrar por ahí falla, que es exactamente lo
 * que debe pasar (ADR-0006).
 */
export async function adminDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5544),
    database: process.env.DB_NAME ?? 'snapline',
    username: process.env.DB_MIGRATION_USERNAME ?? 'snapline_migrator',
    password: process.env.DB_MIGRATION_PASSWORD ?? 'snapline_dev',
  });
  return ds.initialize();
}

export async function bootstrapE2E(): Promise<{ app: INestApplication; ds: DataSource }> {
  initializeTransactionalContext();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalFilters(new HttpExceptionFilter());
  app.setGlobalPrefix('api');
  await app.init();
  return { app, ds: app.get(DataSource) };
}

/** Datos con el rol migrador, que bypassa RLS. Cada suite usa su propia empresa. */
export async function seedCompany(ds: DataSource, label: string): Promise<Fixture> {
  // Sufijo único por corrida: email y teléfono son únicos globales, y las suites
  // anteriores dejan usuarios si algo se cortó a mitad.
  const uniq = `${Date.now()}${Math.floor(performance.now() * 1000) % 1000}`;
  const f: Fixture = {
    companyId: newId(),
    ownerEmail: `owner-${label}-${uniq}@test.local`,
    workerPhone: `+1${uniq.slice(-10).padStart(10, '5')}`,
    password: 'Snapline123!',
    customerId: newId(),
    siteId: newId(),
    projectId: newId(),
    serviceItemId: newId(),
    userIds: [],
    workerMembershipId: '',
  };
  const hash = await AuthService.hashPassword(f.password);
  const ownerUser = newId();
  const workerUser = newId();
  f.userIds = [ownerUser, workerUser];
  const ownerMem = newId();
  const workerMem = newId();
  f.workerMembershipId = workerMem;

  await ds.query(`INSERT INTO company (id,name,public_site_slug) VALUES ($1,$2,$3)`,
    [f.companyId, `Test ${label}`, `test-${label}-${Date.now()}`]);
  await ds.query(`INSERT INTO app_user (id,email,password_hash,name,locale) VALUES ($1,$2,$3,'Owner','en')`,
    [ownerUser, f.ownerEmail, hash]);
  await ds.query(`INSERT INTO app_user (id,phone,password_hash,name,locale) VALUES ($1,$2,$3,'Worker','es')`,
    [workerUser, f.workerPhone, hash]);
  await ds.query(`INSERT INTO membership (id,company_id,user_id,role,status,pay_rate_cents) VALUES ($1,$2,$3,'OWNER','ACTIVE',6500)`,
    [ownerMem, f.companyId, ownerUser]);
  await ds.query(`INSERT INTO membership (id,company_id,user_id,role,status,pay_rate_cents) VALUES ($1,$2,$3,'WORKER','ACTIVE',3200)`,
    [workerMem, f.companyId, workerUser]);
  await ds.query(`INSERT INTO customer (id,company_id,display_name) VALUES ($1,$2,'Cliente Test')`,
    [f.customerId, f.companyId]);
  await ds.query(`INSERT INTO site (id,company_id,customer_id,address,lat,lng,geofence_radius_m)
    VALUES ($1,$2,$3,'{}',39.290385,-76.612189,150)`, [f.siteId, f.companyId, f.customerId]);
  await ds.query(`INSERT INTO project (id,company_id,customer_id,site_id,name,status)
    VALUES ($1,$2,$3,$4,'Obra Test','IN_PROGRESS')`, [f.projectId, f.companyId, f.customerId, f.siteId]);
  await ds.query(`INSERT INTO service_item (id,company_id,name,unit,unit_price_cents,cost_cents,taxable)
    VALUES ($1,$2,'Teja','SQFT',450,210,false)`, [f.serviceItemId, f.companyId]);

  return f;
}

export async function cleanup(ds: DataSource, fixtures: Fixture[]): Promise<void> {
  // El trigger que bloquea DELETE sobre time_entry hace exactamente lo que debe
  // (regla 12), así que limpiar exige desactivarlo a propósito. Solo el rol
  // migrador puede, y solo acá: en runtime no hay forma de borrar horas.
  await ds.query(`ALTER TABLE time_entry DISABLE TRIGGER time_entry_no_hard_delete`);
  try {
    await deleteFixtures(ds, fixtures);
  } finally {
    await ds.query(`ALTER TABLE time_entry ENABLE TRIGGER time_entry_no_hard_delete`);
  }
}

async function deleteFixtures(ds: DataSource, fixtures: Fixture[]): Promise<void> {
  for (const { companyId: id, userIds } of fixtures) {
    // Las tablas de unión no tienen company_id: se borran por su padre.
    await ds.query(`DELETE FROM published_project_asset WHERE published_project_id IN
      (SELECT id FROM published_project WHERE company_id = $1)`, [id]);
    await ds.query(`DELETE FROM project_update_asset WHERE update_id IN
      (SELECT id FROM project_update WHERE company_id = $1)`, [id]);
    await ds.query(`DELETE FROM social_post_asset WHERE social_post_id IN
      (SELECT id FROM social_post WHERE company_id = $1)`, [id]);

    for (const t of ['time_entry_edit', 'time_entry', 'published_project', 'project_update',
      'client_access', 'lead', 'service_offer', 'testimonial', 'social_post',
      'before_after_pair', 'media_tag', 'media_asset', 'payment', 'invoice_line', 'invoice',
      'estimate_line', 'estimate', 'document_counter', 'service_item', 'tax_rate',
      'project_assignment', 'project', 'site', 'customer', 'crew_member', 'crew', 'audit_log']) {
      // Sin catch: si una limpieza falla hay que verlo, no taparlo.
      await ds.query(`DELETE FROM ${t} WHERE company_id = $1`, [id]);
    }
    await ds.query(`DELETE FROM membership WHERE company_id = $1`, [id]);
    await ds.query(`DELETE FROM company WHERE id = $1`, [id]);
    for (const u of userIds) await ds.query(`DELETE FROM app_user WHERE id = $1`, [u]);
  }
}

/** Barre restos de corridas anteriores que se hayan cortado a mitad. */
export async function cleanupOrphans(ds: DataSource): Promise<void> {
  const rows = await ds.query<{ id: string }[]>(
    `SELECT id FROM company WHERE name LIKE 'Test %'`);
  for (const { id } of rows) {
    await ds.query(`DELETE FROM membership WHERE company_id = $1`, [id]).catch(() => undefined);
  }
  await ds.query(`DELETE FROM app_user WHERE email LIKE '%@test.local'`).catch(() => undefined);
}
