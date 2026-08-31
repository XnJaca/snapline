import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { API_BASE_URL } from './api.config';
import { apiInterceptor } from './api.interceptor';
import { SessionService } from '../session/session.service';
import { WebAuthResult } from '../session/session.models';

const BASE = 'http://api.test/api';

const RESULT: WebAuthResult = {
  accessToken: 'access.1',
  expiresInSeconds: 3600,
  user: { id: 'u1', name: 'William', locale: 'en', email: 'w@test.local', phone: null },
  membership: { id: 'm1', companyId: 'c1', companyName: 'PC', role: 'OWNER', permissions: [] },
  memberships: [],
};

describe('apiInterceptor', () => {
  let http: HttpTestingController;
  let client: HttpClient;
  let session: SessionService;

  beforeEach(async () => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([apiInterceptor])),
        provideHttpClientTesting(),
        { provide: API_BASE_URL, useValue: BASE },
      ],
    });
    http = TestBed.inject(HttpTestingController);
    client = TestBed.inject(HttpClient);
    session = TestBed.inject(SessionService);

    const login = session.login('w@test.local', 'Snapline123!');
    http.expectOne(`${BASE}/auth/web/login`).flush(RESULT);
    await login;
  });

  afterEach(() => http.verify());

  it('adjunta el bearer a lo que va al API', () => {
    client.get(`${BASE}/projects`).subscribe();

    const req = http.expectOne(`${BASE}/projects`);
    expect(req.request.headers.get('Authorization')).toBe('Bearer access.1');
    req.flush([]);
  });

  // Las traducciones y los iconos son archivos de la app: mandarles credenciales
  // sería filtrar el token a cualquier CDN que los sirva mañana.
  it('no manda credenciales a los assets propios', () => {
    client.get('/assets/i18n/en.json').subscribe();

    const req = http.expectOne('/assets/i18n/en.json');
    expect(req.request.headers.has('Authorization')).toBe(false);
    req.flush({});
  });

  it('el camino de sesión se autentica con la cookie, no con el bearer', () => {
    client.post(`${BASE}/auth/web/logout`, {}).subscribe();

    const req = http.expectOne(`${BASE}/auth/web/logout`);
    expect(req.request.headers.has('Authorization')).toBe(false);
    req.flush(null);
  });

  /**
   * El criterio: con el access vencido, la llamada se reintenta sola y el usuario
   * no ve un error.
   */
  it('un 401 refresca y reintenta la llamada original', async () => {
    const respuesta = new Promise((resolve) => client.get(`${BASE}/projects`).subscribe(resolve));

    http.expectOne(`${BASE}/projects`)
      .flush({ code: 'TOKEN_INVALID', message: 'x' }, { status: 401, statusText: 'Unauthorized' });

    http.expectOne(`${BASE}/auth/web/refresh`).flush({ ...RESULT, accessToken: 'access.2' });

    const reintento = http.expectOne(`${BASE}/projects`);
    expect(reintento.request.headers.get('Authorization')).toBe('Bearer access.2');
    reintento.flush([{ id: 'p1' }]);

    expect(await respuesta).toEqual([{ id: 'p1' }]);
  });

  it('un 403 no dispara refresh: el permiso no se arregla con otro token', () => {
    client.get(`${BASE}/billing`).subscribe({ error: () => undefined });

    http.expectOne(`${BASE}/billing`)
      .flush({ code: 'PERMISSION_DENIED', message: 'x' }, { status: 403, statusText: 'Forbidden' });

    http.expectNone(`${BASE}/auth/web/refresh`);
  });
});
