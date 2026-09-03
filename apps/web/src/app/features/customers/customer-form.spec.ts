import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { API_BASE_URL } from '../../core/api/api.config';
import { provideI18n } from '../../core/i18n/i18n.config';
import { CustomerForm } from './customer-form/customer-form';

const BASE = 'http://api.test/api';

describe('CustomerForm', () => {
  let http: HttpTestingController;
  let form: CustomerForm;

  beforeEach(() => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        provideI18n(),
        { provide: API_BASE_URL, useValue: BASE },
        // Alta: sin `id` en la ruta.
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => null } } } },
      ],
    });
    http = TestBed.inject(HttpTestingController);
    form = TestBed.runInInjectionContext(() => new CustomerForm());
  });

  afterEach(() => http.verify());

  /** Acceso a los miembros protegidos, que es lo que el template usa. */
  const partes = () => form as unknown as {
    form: { patchValue: (v: Record<string, unknown>) => void };
    phone: { patchValue: (v: Record<string, unknown>) => void };
    site: { patchValue: (v: Record<string, unknown>) => void };
    submit: () => Promise<void>;
    error: () => string | null;
  };

  function llenar(): void {
    const p = partes();
    p.form.patchValue({ displayName: 'Whitaker Home', email: 'w@example.com' });
    p.phone.patchValue({ country: 'US', number: '(555) 447-8890' });
    p.site.patchValue({
      line1: '55 Overlook Dr', city: 'Towson', state: 'MD', postalCode: '21204', country: 'US',
    });
  }

  it('crea el cliente con su primera propiedad en un solo envío', async () => {
    llenar();
    const enviado = partes().submit();

    const req = http.expectOne(`${BASE}/customers`);
    expect(req.request.method).toBe('POST');
    const body = req.request.body as { site?: { address: { line1: string } }; phone: string };
    // La propiedad viaja embebida: el contrato lo soporta y separarlo en dos
    // pantallas obliga a cargar la dirección después.
    expect(body.site?.address.line1).toBe('55 Overlook Dr');
    // Y el teléfono va normalizado, no como lo tecleó quien lo cargó.
    expect(body.phone).toBe('+15554478890');

    req.flush({ id: 'c1', displayName: 'Whitaker Home' });
    await enviado;
  });

  it('no manda cadenas vacías por los campos opcionales', async () => {
    partes().form.patchValue({ displayName: 'Solo el nombre' });
    (form as unknown as { toggleSite: (on: boolean) => void }).toggleSite(false);
    const enviado = partes().submit();

    const req = http.expectOne(`${BASE}/customers`);
    const body = req.request.body as Record<string, unknown>;
    expect(body['firstName']).toBeUndefined();
    expect(body['site']).toBeUndefined();
    expect(body['displayName']).toBe('Solo el nombre');

    req.flush({ id: 'c2', displayName: 'Solo el nombre' });
    await enviado;
  });

  /**
   * El criterio del spec: cargar una dirección completa dos veces es la forma
   * más rápida de que alguien deje de usar el panel.
   */
  it('un fallo de red no pierde lo escrito y se distingue de un error de validación', async () => {
    llenar();
    const enviado = partes().submit();

    http.expectOne(`${BASE}/customers`).error(new ProgressEvent('error'));
    await enviado;

    expect(partes().error()).toBe('connection');
    const valores = (form as unknown as { site: { getRawValue: () => { line1: string } } }).site.getRawValue();
    expect(valores.line1).toBe('55 Overlook Dr');
  });

  it('no navega ni llama al API si falta el nombre', async () => {
    const router = TestBed.inject(Router);
    const navigate = vi.spyOn(router, 'navigate');

    await partes().submit();

    http.expectNone(`${BASE}/customers`);
    expect(navigate).not.toHaveBeenCalled();
  });
});
