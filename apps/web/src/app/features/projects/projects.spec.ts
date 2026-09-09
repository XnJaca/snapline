import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { API_BASE_URL } from '../../core/api/api.config';
import { DatePipe } from '../../core/format/date.pipe';
import { SessionService } from '../../core/session/session.service';
import { WebAuthResult } from '../../core/session/session.models';
import { Projects } from './projects';

const BASE = 'http://api.test/api';

const sesión = (permissions: string[], role: string): WebAuthResult => ({
  accessToken: 'access.1',
  expiresInSeconds: 3600,
  user: { id: 'u1', name: 'Quien sea', locale: 'en', email: 'a@test.local', phone: null },
  membership: { id: 'm1', companyId: 'c1', companyName: 'PC', role, permissions },
  memberships: [],
} as WebAuthResult);

const OBRAS = [
  { id: 'p1', name: 'Techo Martinez', status: 'IN_PROGRESS', customer: { displayName: 'Martinez Residence' } },
  { id: 'p2', name: 'Baño Nguyen', status: 'COMPLETED', customer: { displayName: 'Nguyen Residence' } },
];

describe('Projects', () => {
  let http: HttpTestingController;

  async function montar(permissions: string[], role = 'ADMIN'): Promise<Projects> {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: API_BASE_URL, useValue: BASE },
        // El componente lo declara en sus `providers`, que no aplican al
        // instanciarlo a mano. Se sustituye en vez de proveer el real, que
        // arrastra Transloco entero: acá no se prueban fechas.
        { provide: DatePipe, useValue: { transform: (v: string) => v } },
      ],
    });
    http = TestBed.inject(HttpTestingController);

    const session = TestBed.inject(SessionService);
    const login = session.login('a@test.local', 'Snapline123!');
    http.expectOne(`${BASE}/auth/web/login`).flush(sesión(permissions, role));
    await login;

    const lista = TestBed.runInInjectionContext(() => new Projects());
    TestBed.tick();
    http.expectOne(`${BASE}/projects`).flush(OBRAS);
    TestBed.tick();
    return lista;
  }

  const partes = (p: Projects) => p as unknown as {
    canWrite: () => boolean;
    query: { set: (v: string) => void };
    status: { set: (v: string) => void };
    filtered: () => { id: string }[];
    emptyBySearch: () => boolean;
    emptyByStatus: () => boolean;
  };

  /**
   * El criterio del spec: el capataz y el contador leen y no escriben, así que
   * no pueden encontrar un botón que los lleve a un 403.
   */
  it('un FOREMAN no ve el control de crear obra', async () => {
    const lista = await montar(['projects.read', 'crews.read', 'time.read'], 'FOREMAN');
    expect(partes(lista).canWrite()).toBe(false);
  });

  it('un ACCOUNTANT tampoco', async () => {
    const lista = await montar(['projects.read', 'customers.read', 'reports.read'], 'ACCOUNTANT');
    expect(partes(lista).canWrite()).toBe(false);
  });

  it('quien puede escribir sí', async () => {
    const lista = await montar(['projects.read', 'projects.write']);
    expect(partes(lista).canWrite()).toBe(true);
  });

  /** Los tres vacíos se dicen distinto, y por eso se distinguen acá. */
  it('vacío por búsqueda y vacío por estado no son lo mismo', async () => {
    const lista = await montar(['projects.read', 'projects.write']);
    const p = partes(lista);

    p.query.set('no existe');
    TestBed.tick();
    expect(p.filtered()).toEqual([]);
    expect(p.emptyBySearch()).toBe(true);
    expect(p.emptyByStatus()).toBe(false);

    p.query.set('');
    p.status.set('ON_HOLD');
    TestBed.tick();
    expect(p.emptyByStatus()).toBe(true);
    expect(p.emptyBySearch()).toBe(false);
  });
});
