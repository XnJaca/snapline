import { AfterViewInit, Directive, ElementRef, inject, OnDestroy } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { ScrollMemory } from './scroll-memory';

/**
 * Guarda y devuelve la posición del contenedor al cambiar de eje. El router solo
 * restaura scroll al volver con el botón del navegador, y acá se navega de
 * costado.
 *
 * La clave sale de la ruta y no de una entrada: dos ejes no pueden compartirla
 * por descuido.
 */
@Directive({ selector: '[slKeepScroll]' })
export class KeepScroll implements AfterViewInit, OnDestroy {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);
  private readonly memory = inject(ScrollMemory);
  private readonly route = inject(ActivatedRoute);

  ngAfterViewInit(): void {
    this.host.nativeElement.scrollTop = this.memory.restore(this.key());
  }

  ngOnDestroy(): void {
    this.memory.save(this.key(), this.host.nativeElement.scrollTop);
  }

  private key(): string {
    return this.route.snapshot.routeConfig?.path ?? '';
  }
}
