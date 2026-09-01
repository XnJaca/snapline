import { Injectable } from '@angular/core';

/** Dónde quedó cada eje. Vive en memoria: es estado de sesión, no preferencia. */
@Injectable({ providedIn: 'root' })
export class ScrollMemory {
  private readonly positions = new Map<string, number>();

  save(key: string, top: number): void {
    this.positions.set(key, top);
  }

  restore(key: string): number {
    return this.positions.get(key) ?? 0;
  }
}
