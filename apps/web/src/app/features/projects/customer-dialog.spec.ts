import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { MatDialogRef } from '@angular/material/dialog';
import { API_BASE_URL } from '../../core/api/api.config';
import { CustomerDialog } from './customer-dialog/customer-dialog';

const BASE = 'http://api.test/api';

/** El segundo request se encola recién cuando resuelve la promesa del primero. */
const tick = () => new Promise((r) => setTimeout(r, 0));
const CLIENTE = { id: 'c9', displayName: 'Nuevo Cliente' };
const SITIO = { id: 's9', customerId: 'c9', address: { line1: '1 Nueva', city: 'Bowie' } };

describe('alta de cliente en línea', () => {
  let http: HttpTestingController;
  let cerrado: unknown;

  function montar(): CustomerDialog {
    cerrado = undefined;
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: API_BASE_URL, useValue: BASE },
        { provide: MatDialogRef, useValue: { close: (v: unknown) => (cerrado = v) } },
      ],
    });
    http = TestBed.inject(HttpTestingController);
    return TestBed.runInInjectionContext(() => new CustomerDialog());
  }

  const partes = (d: CustomerDialog) => d as unknown as {
    form: { patchValue: (v: Record<string, unknown>) => void };
    address: { patchValue: (v: Record<string, unknown>) => void };
    error: () => string | null;
    submit: () => Promise<void>;
  };

  const llenar = (d: CustomerDialog) => {
    partes(d).form.patchValue({ displayName: 'Nuevo Cliente' });
    partes(d).address.patchValue({
      line1: '1 Nueva', city: 'Bowie', state: 'MD', postalCode: '20720', country: 'US',
    });
  };

  it('crea el cliente con su propiedad y devuelve las dos', async () => {
    const d = montar();
    llenar(d);

    const enviando = partes(d).submit();
    http.expectOne(`${BASE}/customers`).flush(CLIENTE);
    await tick();
    http.expectOne(`${BASE}/customers/c9/sites`).flush([SITIO]);
    await enviando;

    expect(cerrado).toEqual({ customer: CLIENTE, site: SITIO });
  });

  /**
   * El caso que importa: el cliente ya se creó y falló la lectura de su
   * propiedad. Reintentar no puede dar de alta un segundo cliente con el mismo
   * nombre — SPEC-0009 no deja borrar un cliente al que ya se le colgó una obra.
   */
  it('el reintento no duplica el cliente que ya se creó', async () => {
    const d = montar();
    llenar(d);

    const primero = partes(d).submit();
    http.expectOne(`${BASE}/customers`).flush(CLIENTE);
    await tick();
    http.expectOne(`${BASE}/customers/c9/sites`).error(new ProgressEvent('error'), { status: 0 });
    await primero;
    expect(partes(d).error()).toBe('connection');

    const segundo = partes(d).submit();
    await tick();
    // Ningún POST de nuevo: solo se reintenta lo que faltaba.
    http.expectNone(`${BASE}/customers`);
    http.expectOne(`${BASE}/customers/c9/sites`).flush([SITIO]);
    await segundo;

    expect(cerrado).toEqual({ customer: CLIENTE, site: SITIO });
  });
});
