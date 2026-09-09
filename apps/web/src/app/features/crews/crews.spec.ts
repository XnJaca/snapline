import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { API_BASE_URL } from '../../core/api/api.config';
import { SessionService } from '../../core/session/session.service';
import { WebAuthResult } from '../../core/session/session.models';
import { TranslocoService } from '@jsverse/transloco';
import { MatDialog } from '@angular/material/dialog';
import { Crews } from './crews';

const BASE = 'http://api.test/api';

type Rol = WebAuthResult['membership']['role'];

const sesión = (permissions: string[], role: Rol): WebAuthResult => ({
  accessToken: 'access.1',
  expiresInSeconds: 3600,
  user: { id: 'u1', name: 'Quien sea', locale: 'es', email: 'a@test.local', phone: null },
  membership: { id: 'm1', companyId: 'c1', companyName: 'PC', role, permissions },
  memberships: [],
});

const CUADRILLAS = [
  { id: 'cr1', name: 'Cuadrilla A', color: '#2563eb', foreman: null, memberCount: 2 },
];

/**
 * La tarifa de cada persona sale por `/memberships` y por ninguna otra vía, así
 * que quién puede pedirla no es un detalle de pantalla: es el criterio del spec.
 */
describe('Cuadrillas', () => {
  let http: HttpTestingController;

  async function montar(permissions: string[], role: Rol = 'OWNER'): Promise<Crews> {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: API_BASE_URL, useValue: BASE },
        // La pantalla los inyecta para los diálogos; acá se prueba el gating de
        // permisos, no lo que el diálogo dice.
        { provide: TranslocoService, useValue: { translate: (k: string) => k, getActiveLang: () => 'es' } },
        { provide: MatDialog, useValue: { open: () => ({ afterClosed: () => ({ toPromise: async () => null }) }) } },
      ],
    });
    http = TestBed.inject(HttpTestingController);

    const session = TestBed.inject(SessionService);
    const login = session.login('a@test.local', 'Snapline123!');
    http.expectOne(`${BASE}/auth/web/login`).flush(sesión(permissions, role));
    await login;

    const pantalla = TestBed.runInInjectionContext(() => new Crews());
    TestBed.tick();
    return pantalla;
  }

  const partes = (c: Crews) =>
    c as unknown as { canManage: () => boolean; canWrite: () => boolean };

  it('el capataz ve cuadrillas y no la pestaña de trabajadores', async () => {
    const pantalla = await montar(['crews.read', 'projects.read'], 'FOREMAN');
    http.expectOne(`${BASE}/crews`).flush(CUADRILLAS);
    TestBed.tick();

    expect(partes(pantalla).canManage()).toBe(false);
    expect(partes(pantalla).canWrite()).toBe(false);

    // Y no pide las tarifas: sin el permiso, esa petición devolvería 403, y una
    // URL vacía pedía la raíz del API — un 404 por cada carga.
    http.expectNone(`${BASE}/memberships`);
    http.expectNone(BASE);
  });

  it('el dueño sí las pide', async () => {
    const pantalla = await montar([
      'crews.read', 'crews.write', 'members.manage', 'projects.read',
    ]);
    http.expectOne(`${BASE}/crews`).flush(CUADRILLAS);
    http.expectOne(`${BASE}/memberships`).flush([]);
    TestBed.tick();

    expect(partes(pantalla).canManage()).toBe(true);
    expect(partes(pantalla).canWrite()).toBe(true);
  });

  it('quien lee cuadrillas pero no las escribe no encuentra cómo crearlas', async () => {
    const pantalla = await montar(['crews.read', 'members.manage', 'projects.read']);
    http.expectOne(`${BASE}/crews`).flush(CUADRILLAS);
    http.expectOne(`${BASE}/memberships`).flush([]);
    TestBed.tick();

    expect(partes(pantalla).canWrite()).toBe(false);
    expect(partes(pantalla).canManage()).toBe(true);
  });

  afterEach(() => http.verify());
});
