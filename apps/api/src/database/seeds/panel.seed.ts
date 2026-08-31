import { DataSource } from 'typeorm';
import { obtenerOCrear } from './seed-helpers';

export interface ContextoPanel {
  companyId: string;
  ownerMembershipId: string;
  foremanMembershipId: string;
  workerMembershipId: string;
}

interface ClienteSemilla {
  displayName: string;
  email: string;
  phone: string;
  source: string;
  line1: string;
  city: string;
  postalCode: string;
}

const CLIENTES: ClienteSemilla[] = [
  { displayName: 'Nguyen Residence', email: 'nguyen@example.com', phone: '+15553312244',
    source: 'WEB', line1: '812 Cedar Ln', city: 'Rockville', postalCode: '20850' },
  { displayName: 'Whitaker Home', email: 'whitaker@example.com', phone: '+15554478890',
    source: 'REPEAT', line1: '55 Overlook Dr', city: 'Towson', postalCode: '21204' },
  { displayName: 'Delgado Property Group', email: 'ops@delgadopg.com', phone: '+15556620011',
    source: 'REFERRAL', line1: '2400 Commerce Way', city: 'Frederick', postalCode: '21701' },
];

interface ProyectoSemilla {
  cliente: string;
  name: string;
  serviceType: string;
  status: string;
  description: string;
  inicioHace: number;
  finEn: number;
}

const PROYECTOS: ProyectoSemilla[] = [
  { cliente: 'Nguyen Residence', name: 'Terraza Nguyen', serviceType: 'deck', status: 'SCHEDULED',
    description: 'Terraza de madera tratada de 18 por 14 pies, con baranda y gradas al jardín.',
    inicioHace: -6, finEn: 21 },
  { cliente: 'Whitaker Home', name: 'Siding Whitaker', serviceType: 'siding', status: 'ESTIMATED',
    description: 'Cambio de siding de vinil en las cuatro caras de la casa.', inicioHace: -1, finEn: 40 },
  { cliente: 'Delgado Property Group', name: 'Techo Commerce Way', serviceType: 'roofing', status: 'COMPLETED',
    description: 'Techo plano con membrana TPO sobre la bodega.', inicioHace: 95, finEn: -35 },
  { cliente: 'Whitaker Home', name: 'Cocina Whitaker', serviceType: 'kitchen', status: 'ON_HOLD',
    description: 'Remodelación de cocina. En pausa hasta que llegue el gabinete.', inicioHace: 30, finEn: 25 },
];

const ITEMS = [
  { code: 'ROOF-TPO', name: 'Membrana TPO', unit: 'SQFT', precio: 890, costo: 420, cat: 'Techos' },
  { code: 'DECK-PT', name: 'Terraza de madera tratada', unit: 'SQFT', precio: 3400, costo: 1900, cat: 'Exteriores' },
  { code: 'SID-VIN', name: 'Siding de vinil', unit: 'SQFT', precio: 760, costo: 380, cat: 'Exteriores' },
  { code: 'LAB-GEN', name: 'Mano de obra general', unit: 'HOUR', precio: 6500, costo: 3800, cat: 'Mano de obra' },
  { code: 'DUMP', name: 'Alquiler de contenedor', unit: 'EACH', precio: 45000, costo: 32000, cat: 'Logística' },
];

/**
 * Lo que el panel necesita para no verse vacío: varias obras en distintos
 * estados, horas de las dos personas de campo, catálogo y un ciclo comercial
 * completo.
 *
 * No siembra publicaciones: publicar exige una foto con el EXIF ya limpio y un
 * objeto real en el bucket, y sin credenciales de Backblaze eso sería una tarjeta
 * con la imagen rota. La pantalla muestra su estado vacío, que es lo que William
 * ve hoy de verdad.
 */
export async function sembrarPanel(ds: DataSource, ctx: ContextoPanel): Promise<void> {
  const { companyId, ownerMembershipId, foremanMembershipId, workerMembershipId } = ctx;
  const proyectoPorNombre = new Map<string, string>();

  for (const c of CLIENTES) {
    const customerId = await obtenerOCrear(
      ds, 'customer', 'company_id = $1 AND display_name = $2', [companyId, c.displayName],
      (id) => ds.query(
        `INSERT INTO customer (id, company_id, display_name, email, phone, source)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [id, companyId, c.displayName, c.email, c.phone, c.source],
      ),
    );

    await obtenerOCrear(
      ds, 'site', `customer_id = $1 AND address->>'line1' = $2`, [customerId, c.line1],
      (id) => ds.query(
        `INSERT INTO site (id, company_id, customer_id, address, lat, lng, geofence_radius_m)
         VALUES ($1,$2,$3,$4,39.290385,-76.612189,150)`,
        [id, companyId, customerId, JSON.stringify({
          line1: c.line1, city: c.city, state: 'MD', postalCode: c.postalCode, country: 'US',
        })],
      ),
    );
  }

  for (const p of PROYECTOS) {
    const [cliente] = await ds.query<Array<{ id: string }>>(
      `SELECT id FROM customer WHERE company_id = $1 AND display_name = $2`, [companyId, p.cliente]);
    const [sitio] = await ds.query<Array<{ id: string }>>(
      `SELECT id FROM site WHERE customer_id = $1 ORDER BY created_at LIMIT 1`, [cliente.id]);

    const projectId = await obtenerOCrear(
      ds, 'project', 'company_id = $1 AND name = $2', [companyId, p.name],
      (id) => ds.query(
        `INSERT INTO project (id, company_id, customer_id, site_id, name, service_type, status,
                              description, start_date, target_end_date)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8, CURRENT_DATE - $9::int, CURRENT_DATE + $10::int)`,
        [id, companyId, cliente.id, sitio.id, p.name, p.serviceType, p.status,
         p.description, p.inicioHace, p.finEn],
      ),
    );
    proyectoPorNombre.set(p.name, projectId);
  }

  for (const i of ITEMS) {
    await obtenerOCrear(
      ds, 'service_item', 'company_id = $1 AND name = $2', [companyId, i.name],
      (id) => ds.query(
        `INSERT INTO service_item (id, company_id, code, name, unit, unit_price_cents, cost_cents, taxable, category)
         VALUES ($1,$2,$3,$4,$5,$6,$7,true,$8)`,
        [id, companyId, i.code, i.name, i.unit, i.precio, i.costo, i.cat],
      ),
    );
  }

  await sembrarHoras(ds, companyId, proyectoPorNombre, { foremanMembershipId, workerMembershipId, ownerMembershipId });
  await sembrarComercial(ds, companyId, proyectoPorNombre, ownerMembershipId);
}

async function sembrarHoras(
  ds: DataSource,
  companyId: string,
  proyectos: Map<string, string>,
  m: { foremanMembershipId: string; workerMembershipId: string; ownerMembershipId: string },
): Promise<void> {
  const [techo] = await ds.query<Array<{ id: string }>>(
    `SELECT id FROM project WHERE company_id = $1 AND name = 'Techo Martinez'`, [companyId]);
  const terraza = proyectos.get('Terraza Nguyen');
  if (!techo || !terraza) return;

  // Tarifa congelada al aprobar (regla 13): la del trabajador y la de la capataza.
  const jornadas: Array<{
    proyecto: string; quien: string; hace: number; horas: number;
    estado: string; tarifa: number | null; flags: string[];
  }> = [
    { proyecto: techo.id, quien: m.workerMembershipId, hace: 6, horas: 8, estado: 'APPROVED', tarifa: 3200, flags: [] },
    { proyecto: techo.id, quien: m.foremanMembershipId, hace: 6, horas: 8, estado: 'APPROVED', tarifa: 4500, flags: [] },
    { proyecto: techo.id, quien: m.workerMembershipId, hace: 5, horas: 7.5, estado: 'APPROVED', tarifa: 3200, flags: [] },
    { proyecto: techo.id, quien: m.foremanMembershipId, hace: 5, horas: 7.5, estado: 'APPROVED', tarifa: 4500, flags: [] },
    // Fuera de la geocerca: es la bandera que el panel tiene que dejar ver.
    { proyecto: terraza, quien: m.workerMembershipId, hace: 4, horas: 6, estado: 'PENDING', tarifa: null, flags: ['OUTSIDE_GEOFENCE'] },
    { proyecto: terraza, quien: m.foremanMembershipId, hace: 4, horas: 8, estado: 'PENDING', tarifa: null, flags: [] },
    { proyecto: terraza, quien: m.workerMembershipId, hace: 3, horas: 8, estado: 'PENDING', tarifa: null, flags: [] },
    { proyecto: techo.id, quien: m.workerMembershipId, hace: 2, horas: 4.5, estado: 'REJECTED', tarifa: null, flags: ['NO_GPS'] },
    { proyecto: techo.id, quien: m.foremanMembershipId, hace: 1, horas: 8, estado: 'PENDING', tarifa: null, flags: [] },
  ];

  for (const j of jornadas) {
    await obtenerOCrear(
      ds, 'time_entry',
      `company_id = $1 AND membership_id = $2 AND clock_in_at::date = (CURRENT_DATE - $3::int)`,
      [companyId, j.quien, j.hace],
      (id) => ds.query(
        `INSERT INTO time_entry (
           id, company_id, project_id, membership_id,
           clock_in_at, clock_out_at, break_minutes,
           clock_in_within_geofence, method, recorded_by_membership_id,
           device_recorded_at, server_received_at, status, pay_rate_cents_snapshot,
           approved_by_membership_id, approved_at, flags)
         VALUES ($1,$2,$3,$4,
           (CURRENT_DATE - $5::int) + time '07:00', (CURRENT_DATE - $5::int) + time '07:00' + ($6 || ' hours')::interval,
           30, $7, 'SELF', $4,
           (CURRENT_DATE - $5::int) + time '07:00', now(), $8, $9,
           $10, $11, $12)`,
        [id, companyId, j.proyecto, j.quien, j.hace, j.horas,
         !j.flags.includes('OUTSIDE_GEOFENCE'), j.estado, j.tarifa,
         j.estado === 'PENDING' ? null : m.ownerMembershipId,
         j.estado === 'PENDING' ? null : new Date(),
         j.flags],
      ),
    );
  }
}

async function sembrarComercial(
  ds: DataSource,
  companyId: string,
  proyectos: Map<string, string>,
  ownerMembershipId: string,
): Promise<void> {
  const siding = proyectos.get('Siding Whitaker');
  const techoCommerce = proyectos.get('Techo Commerce Way');
  if (!siding || !techoCommerce) return;

  const [whitaker] = await ds.query<Array<{ id: string }>>(
    `SELECT id FROM customer WHERE company_id = $1 AND display_name = 'Whitaker Home'`, [companyId]);
  const [delgado] = await ds.query<Array<{ id: string }>>(
    `SELECT id FROM customer WHERE company_id = $1 AND display_name = 'Delgado Property Group'`, [companyId]);

  const estimateId = await obtenerOCrear(
    ds, 'estimate', 'company_id = $1 AND number = $2', [companyId, 'EST-1001'],
    (id) => ds.query(
      `INSERT INTO estimate (id, company_id, customer_id, project_id, number, status,
                             issued_at, expires_at, subtotal_cents, tax_cents, total_cents)
       VALUES ($1,$2,$3,$4,'EST-1001','SENT', now() - interval '9 days', now() + interval '21 days',
               1824000, 109440, 1933440)`,
      [id, companyId, whitaker.id, siding],
    ),
  );
  await agregarLinea(ds, 'estimate_line', 'estimate_id', estimateId, companyId,
    'Siding de vinil', 'SQFT', 760, 2400, 1824000);

  // Factura enviada y sin pagos: es la que se ve como pendiente de cobro.
  const enviada = await obtenerOCrear(
    ds, 'invoice', 'company_id = $1 AND number = $2', [companyId, 'INV-1001'],
    (id) => ds.query(
      `INSERT INTO invoice (id, company_id, customer_id, project_id, number, status,
                            issued_at, due_at, subtotal_cents, tax_cents, total_cents, balance_cents)
       VALUES ($1,$2,$3,$4,'INV-1001','SENT', now() - interval '18 days', now() - interval '3 days',
               890000, 53400, 943400, 943400)`,
      [id, companyId, delgado.id, techoCommerce],
    ),
  );
  await agregarLinea(ds, 'invoice_line', 'invoice_id', enviada, companyId,
    'Membrana TPO', 'SQFT', 890, 1000, 890000);

  // Y una con abono, para ver el saldo distinto del total.
  const parcial = await obtenerOCrear(
    ds, 'invoice', 'company_id = $1 AND number = $2', [companyId, 'INV-1002'],
    (id) => ds.query(
      `INSERT INTO invoice (id, company_id, customer_id, project_id, number, status,
                            issued_at, due_at, subtotal_cents, tax_cents, total_cents, balance_cents)
       VALUES ($1,$2,$3,$4,'INV-1002','PARTIAL', now() - interval '6 days', now() + interval '9 days',
               620000, 37200, 657200, 257200)`,
      [id, companyId, whitaker.id, siding],
    ),
  );
  await agregarLinea(ds, 'invoice_line', 'invoice_id', parcial, companyId,
    'Mano de obra general', 'HOUR', 6500, 95.385, 620000);

  await obtenerOCrear(
    ds, 'payment', 'invoice_id = $1', [parcial],
    (id) => ds.query(
      `INSERT INTO payment (id, company_id, invoice_id, amount_cents, method, received_at,
                            reference, recorded_by_membership_id)
       VALUES ($1,$2,$3,400000,'CHECK', now() - interval '2 days', 'Cheque 4471', $4)`,
      [id, companyId, parcial, ownerMembershipId],
    ),
  );

  // El contador queda por delante de lo sembrado: si no, el primer documento que
  // emita la app choca con el número de acá.
  for (const tipo of ['ESTIMATE', 'INVOICE']) {
    await ds.query(
      `INSERT INTO document_counter (company_id, doc_type, next_number) VALUES ($1,$2,1003)
       ON CONFLICT (company_id, doc_type) DO UPDATE SET next_number = GREATEST(document_counter.next_number, 1003)`,
      [companyId, tipo],
    );
  }
}

async function agregarLinea(
  ds: DataSource,
  tabla: string,
  columnaPadre: string,
  padreId: string,
  companyId: string,
  nombre: string,
  unidad: string,
  precio: number,
  cantidad: number,
  monto: number,
): Promise<void> {
  const [item] = await ds.query<Array<{ id: string }>>(
    `SELECT id FROM service_item WHERE company_id = $1 AND name = $2`, [companyId, nombre]);

  await obtenerOCrear(
    ds, tabla, `${columnaPadre} = $1 AND position = 1`, [padreId],
    (id) => ds.query(
      `INSERT INTO ${tabla} (id, company_id, ${columnaPadre}, position, service_item_id,
                             name_snapshot, unit_snapshot, taxable_snapshot,
                             unit_price_cents_snapshot, qty, amount_cents)
       VALUES ($1,$2,$3,1,$4,$5,$6,true,$7,$8,$9)`,
      [id, companyId, padreId, item?.id ?? null, nombre, unidad, precio, cantidad, monto],
    ),
  );
}
