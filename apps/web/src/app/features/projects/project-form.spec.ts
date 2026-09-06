import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { MatDialog } from '@angular/material/dialog';
import { API_BASE_URL } from '../../core/api/api.config';
import { ProjectForm } from './project-form/project-form';

const BASE = 'http://api.test/api';

const CLIENTES = [{ id: 'c1', displayName: 'Martinez Residence' }];
const SITIOS = [{ id: 's1', customerId: 'c1', address: { line1: '100 Main St', city: 'Baltimore' } }];

/** El diálogo se reemplaza por lo que devolvería al cerrarse. */
const dialogoQueDevuelve = (valor: unknown) => ({
  open: () => ({ afterClosed: () => ({ toPromise: () => Promise.resolve(valor) }) }),
});

describe('alta de obra', () => {
  let http: HttpTestingController;

  function montar(dialog: unknown = dialogoQueDevuelve(null)): ProjectForm {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: API_BASE_URL, useValue: BASE },
        { provide: MatDialog, useValue: dialog },
      ],
    });
    http = TestBed.inject(HttpTestingController);
    const form = TestBed.runInInjectionContext(() => new ProjectForm());
    http.expectOne(`${BASE}/customers`).flush(CLIENTES);
    return form;
  }

  const partes = (f: ProjectForm) => f as unknown as {
    form: { patchValue: (v: Record<string, unknown>) => void; controls: Record<string, { value: string }> };
    sites: () => { id: string }[];
    error: () => string | null;
    onCustomer: (id: string) => Promise<void>;
    newCustomer: () => Promise<void>;
    newSite: () => Promise<void>;
    submit: () => Promise<void>;
  };

  it('elegir cliente carga sus propiedades', async () => {
    const f = partes(montar());
    const cargando = f.onCustomer('c1');
    http.expectOne(`${BASE}/customers/c1/sites`).flush(SITIOS);
    await cargando;

    expect(f.sites()).toHaveLength(1);
  });

  /**
   * El criterio del spec: es la única forma de que el par no quede cruzado si
   * alguien vuelve atrás en el formulario.
   */
  it('elegir otro cliente vacía la propiedad elegida', async () => {
    const f = partes(montar());
    const primera = f.onCustomer('c1');
    http.expectOne(`${BASE}/customers/c1/sites`).flush(SITIOS);
    await primera;
    f.form.patchValue({ siteId: 's1' });

    const segunda = f.onCustomer('c2');
    http.expectOne(`${BASE}/customers/c2/sites`).flush([]);
    await segunda;

    expect(f.form.controls['siteId'].value).toBe('');
    expect(f.sites()).toEqual([]);
  });

  it('el cliente creado en el diálogo vuelve elegido, con su propiedad', async () => {
    const creado = {
      customer: { id: 'c9', displayName: 'Nuevo Cliente' },
      site: { id: 's9', address: { line1: '1 Nueva', city: 'Rockville' } },
    };
    const f = partes(montar(dialogoQueDevuelve(creado)));
    await f.newCustomer();

    expect(f.form.controls['customerId'].value).toBe('c9');
    expect(f.form.controls['siteId'].value).toBe('s9');
    expect(f.sites()).toEqual([creado.site]);
  });

  it('la propiedad creada en el diálogo vuelve elegida', async () => {
    const nueva = { id: 's9', address: { line1: '2 Nueva', city: 'Bowie' } };
    const f = partes(montar(dialogoQueDevuelve(nueva)));
    f.form.patchValue({ customerId: 'c1' });
    await f.newSite();

    expect(f.form.controls['siteId'].value).toBe('s9');
    expect(f.sites()).toContain(nueva);
  });

  /**
   * El criterio del spec: cargar dos veces lo mismo es lo que hace que alguien
   * deje de usar el panel. Y lo creado en un diálogo no se deshace.
   */
  it('un fallo de red conserva lo escrito y no borra lo ya creado', async () => {
    const f = partes(montar());
    f.form.patchValue({ customerId: 'c1', siteId: 's1', name: 'Techo Martinez' });

    const enviando = f.submit();
    http.expectOne(`${BASE}/projects`).error(new ProgressEvent('error'), { status: 0 });
    await enviando;

    expect(f.error()).toBe('connection');
    expect(f.form.controls['name'].value).toBe('Techo Martinez');
    expect(f.form.controls['customerId'].value).toBe('c1');
    // Ningún DELETE de rescate: el cliente que se creó en el diálogo ya existe.
    http.expectNone(`${BASE}/customers/c1`);
  });

  it('no envía sin cliente, propiedad y nombre', async () => {
    const f = partes(montar());
    await f.submit();
    http.expectNone(`${BASE}/projects`);
  });
});
