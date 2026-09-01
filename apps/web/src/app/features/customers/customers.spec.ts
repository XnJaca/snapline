import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { API_BASE_URL } from '../../core/api/api.config';
import { SessionService } from '../../core/session/session.service';
import { WebAuthResult } from '../../core/session/session.models';
import { Customers } from './customers';

const BASE = 'http://api.test/api';

const sesión = (permissions: string[]): WebAuthResult => ({
  accessToken: 'access.1',
  expiresInSeconds: 3600,
  user: { id: 'u1', name: 'Quien sea', locale: 'en', email: 'a@test.local', phone: null },
  membership: { id: 'm1', companyId: 'c1', companyName: 'PC', role: 'ACCOUNTANT', permissions },
  memberships: [],
});

const CLIENTES = [
  { id: 'c1', displayName: 'Martinez Residence', email: 'martinez@example.com', phone: '+15559876543' },
  { id: 'c2', displayName: 'Whitaker Home', email: null, phone: '+15554478890' },
];

describe('Customers', () => {
  let http: HttpTestingController;

  async function montar(permissions: string[]): Promise<Customers> {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: API_BASE_URL, useValue: BASE },
      ],
    });
    http = TestBed.inject(HttpTestingController);

    const session = TestBed.inject(SessionService);
    const login = session.login('a@test.local', 'Snapline123!');
    http.expectOne(`${BASE}/auth/web/login`).flush(sesión(permissions));
    await login;

    const lista = TestBed.runInInjectionContext(() => new Customers());
    TestBed.tick();
    return lista;
  }

  const partes = (c: Customers) => c as unknown as { canWrite: () => boolean };

  /**
   * El criterio del spec: el contador lee y no escribe, así que no puede
   * encontrar un botón que lo lleve a un 403.
   */
  it('quien solo lee no ve ningún control de escritura', async () => {
    const lista = await montar(['customers.read', 'projects.read', 'reports.read']);
    http.expectOne(`${BASE}/customers`).flush(CLIENTES);
    TestBed.tick();

    expect(partes(lista).canWrite()).toBe(false);
  });

  it('quien puede escribir sí', async () => {
    const lista = await montar(['customers.read', 'customers.write']);
    http.expectOne(`${BASE}/customers`).flush(CLIENTES);
    TestBed.tick();

    expect(partes(lista).canWrite()).toBe(true);
  });
});
