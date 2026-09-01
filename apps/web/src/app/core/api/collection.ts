import { inject } from '@angular/core';
import { httpResource, HttpResourceRef } from '@angular/common/http';
import { API_BASE_URL } from './api.config';

/**
 * Una colección del API como recurso: valor, carga y error en señales, y el
 * reintento gratis. Pasa por el interceptor, así que lleva el bearer y refresca
 * sola cuando el access vence.
 */
export function collection<T>(path: () => string): HttpResourceRef<T[]> {
  const base = inject(API_BASE_URL);
  return httpResource<T[]>(() => `${base}${path()}`, { defaultValue: [] });
}
