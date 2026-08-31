import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { API_BASE_URL } from '../api/api.config';
import { SessionService } from './session.service';
import { WebAuthResult } from './session.models';

const BASE = 'http://api.test/api';

const RESULT: WebAuthResult = {
  accessToken: 'access.1',
  expiresInSeconds: 3600,
  user: { id: 'u1', name: 'William Ferman', locale: 'en', email: 'w@test.local', phone: null },
  membership: {
    id: 'm1', companyId: 'c1', companyName: 'Professional Construction',
    role: 'OWNER', permissions: ['projects.read', 'billing.read'],
  },
  memberships: [],
};

function stubStorages(): void {
  const empty = (): Storage => {
    const data = new Map<string, string>();
    return {
      get length() { return data.size; },
      clear: () => data.clear(),
      getItem: (key) => data.get(key) ?? null,
      key: (index) => [...data.keys()][index] ?? null,
      removeItem: (key) => void data.delete(key),
      setItem: (key, value) => void data.set(key, value),
    };
  };
  for (const name of ['localStorage', 'sessionStorage']) {
    Object.defineProperty(globalThis, name, { value: empty(), configurable: true });
  }
}

describe('SessionService', () => {
  let service: SessionService;
  let http: HttpTestingController;

  beforeEach(() => {
    stubStorages();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: API_BASE_URL, useValue: BASE },
      ],
    });
    service = TestBed.inject(SessionService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('el token queda en memoria y el navegador no guarda nada', async () => {
    const done = service.login('w@test.local', 'Snapline123!');
    const req = http.expectOne(`${BASE}/auth/web/login`);
    // Sin esto la cookie no viaja: el panel llama al API desde otro origen.
    expect(req.request.withCredentials).toBe(true);
    req.flush(RESULT);
    await done;

    expect(service.accessToken()).toBe('access.1');
    expect(service.status()).toBe('authenticated');
    expect(localStorage.length).toBe(0);
    expect(sessionStorage.length).toBe(0);
  });

  it('los permisos salen del login, no de una tabla propia', async () => {
    const done = service.login('w@test.local', 'Snapline123!');
    http.expectOne(`${BASE}/auth/web/login`).flush(RESULT);
    await done;

    expect(service.can('billing.read')).toBe(true);
    expect(service.can('crews.read')).toBe(false);
  });

  it('recargar entra con la cookie sola, sin cuerpo', async () => {
    const done = service.restore();
    const req = http.expectOne(`${BASE}/auth/web/refresh`);
    expect(req.request.withCredentials).toBe(true);
    req.flush(RESULT);
    await done;

    expect(service.status()).toBe('authenticated');
  });

  it('dos refresh a la vez son una sola llamada', async () => {
    const first = service.refresh();
    const second = service.refresh();
    const subscriptions = Promise.all([
      new Promise((resolve) => first.subscribe(resolve)),
      new Promise((resolve) => second.subscribe(resolve)),
    ]);

    http.expectOne(`${BASE}/auth/web/refresh`).flush(RESULT);

    expect(await subscriptions).toEqual(['access.1', 'access.1']);
  });

  it('un 401 deja la sesión afuera', async () => {
    const done = service.restore();
    http.expectOne(`${BASE}/auth/web/refresh`)
      .flush({ code: 'TOKEN_INVALID', message: 'x' }, { status: 401, statusText: 'Unauthorized' });
    await done;

    expect(service.status()).toBe('anonymous');
    expect(service.accessToken()).toBeNull();
  });

  /**
   * La diferencia que el spec pide sostener: sin red no hay respuesta HTTP, así
   * que tampoco hay credenciales rechazadas.
   */
  it('un fallo de red deja offline, no anonymous', async () => {
    const done = service.restore();
    http.expectOne(`${BASE}/auth/web/refresh`).error(new ProgressEvent('error'));
    await done;

    expect(service.status()).toBe('offline');
  });

  it('cerrar sesión olvida el token aunque el servidor no conteste, y avisa', async () => {
    const login = service.login('w@test.local', 'Snapline123!');
    http.expectOne(`${BASE}/auth/web/login`).flush(RESULT);
    await login;

    const done = service.logout();
    http.expectOne(`${BASE}/auth/web/logout`).error(new ProgressEvent('error'));
    // El fallo sube: sin respuesta, el contador del servidor no aumentó.
    await expect(done).rejects.toBeDefined();

    expect(service.accessToken()).toBeNull();
    expect(service.status()).toBe('anonymous');
    expect(service.user()).toBeNull();
  });
});
