import { TestBed } from '@angular/core/testing';
import { ThemeService } from './theme.service';

/**
 * El entorno del builder trae `document` pero no `localStorage`. El stub va acá y
 * no en el servicio: inyectar el storage solo para poder testearlo sería diseñar
 * para el test.
 */
function stubStorage(): Storage {
  const data = new Map<string, string>();
  const storage: Storage = {
    get length() {
      return data.size;
    },
    clear: () => data.clear(),
    getItem: (key) => data.get(key) ?? null,
    key: (index) => [...data.keys()][index] ?? null,
    removeItem: (key) => void data.delete(key),
    setItem: (key, value) => void data.set(key, value),
  };
  Object.defineProperty(globalThis, 'localStorage', { value: storage, configurable: true });
  return storage;
}

describe('ThemeService', () => {
  let storage: Storage;

  beforeEach(() => {
    storage = stubStorage();
    document.documentElement.removeAttribute('data-theme');
    TestBed.resetTestingModule();
  });

  it('arranca en system, sin escribir el atributo', () => {
    const service = TestBed.inject(ThemeService);
    TestBed.tick();

    expect(service.mode()).toBe('system');
    // Sin atributo manda prefers-color-scheme, que es lo que el SCSS resuelve.
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('forzar un tema lo escribe en el atributo y lo persiste', () => {
    const service = TestBed.inject(ThemeService);
    TestBed.tick();

    service.set('dark');
    TestBed.tick();

    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
    expect(storage.getItem('sl.theme')).toBe('dark');
  });

  it('volver a system limpia el atributo y lo guardado', () => {
    const service = TestBed.inject(ThemeService);
    TestBed.tick();
    service.set('light');
    TestBed.tick();

    service.set('system');
    TestBed.tick();

    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
    expect(storage.getItem('sl.theme')).toBeNull();
  });

  it('restaura la elección guardada al arrancar', () => {
    storage.setItem('sl.theme', 'dark');

    const service = TestBed.inject(ThemeService);
    TestBed.tick();

    expect(service.mode()).toBe('dark');
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });

  it('un valor basura en storage no rompe: cae en system', () => {
    storage.setItem('sl.theme', 'neon');

    const service = TestBed.inject(ThemeService);
    TestBed.tick();

    expect(service.mode()).toBe('system');
  });

  it('sin storage disponible el tema igual se aplica', () => {
    // Safari en modo privado tira al tocar localStorage. Quedarse sin tema por eso
    // sería peor que no recordar la preferencia.
    Object.defineProperty(globalThis, 'localStorage', {
      get() {
        throw new Error('SecurityError');
      },
      configurable: true,
    });

    const service = TestBed.inject(ThemeService);
    TestBed.tick();
    service.set('dark');
    TestBed.tick();

    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });
});
