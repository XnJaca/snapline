import { ElementRef } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { KeepScroll } from './keep-scroll.directive';
import { ScrollMemory } from './scroll-memory';

/**
 * Cambiar de eje y volver tiene que dejar la lista donde estaba. Es el criterio
 * que obliga a que cada destino tenga una lista scrolleable de verdad.
 */
describe('KeepScroll', () => {
  const element = () => ({ scrollTop: 0 }) as HTMLElement;

  function mount(host: HTMLElement, path: string): KeepScroll {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: ElementRef, useValue: new ElementRef(host) },
        { provide: ActivatedRoute, useValue: { snapshot: { routeConfig: { path } } } },
        { provide: ScrollMemory, useValue: memory },
      ],
    });
    const directive = TestBed.runInInjectionContext(() => new KeepScroll());
    directive.ngAfterViewInit();
    return directive;
  }

  let memory: ScrollMemory;

  beforeEach(() => (memory = new ScrollMemory()));

  it('devuelve la lista a donde estaba al volver al eje', () => {
    const primera = element();
    const directive = mount(primera, 'projects');
    primera.scrollTop = 420;
    directive.ngOnDestroy();

    const segunda = element();
    mount(segunda, 'projects');

    expect(segunda.scrollTop).toBe(420);
  });

  it('cada eje recuerda la suya', () => {
    const proyectos = element();
    const conProyectos = mount(proyectos, 'projects');
    proyectos.scrollTop = 420;
    conProyectos.ngOnDestroy();

    const clientes = element();
    mount(clientes, 'customers');

    expect(clientes.scrollTop).toBe(0);
  });

  it('un eje que nunca se scrolleó arranca arriba', () => {
    const nuevo = element();
    mount(nuevo, 'reports');

    expect(nuevo.scrollTop).toBe(0);
  });
});
