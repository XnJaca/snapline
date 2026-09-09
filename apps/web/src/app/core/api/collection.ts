import { inject } from '@angular/core';
import { httpResource, HttpResourceRef } from '@angular/common/http';
import { API_BASE_URL } from './api.config';

/**
 * Una colección del API como recurso: valor, carga y error en señales, y el
 * reintento gratis. Pasa por el interceptor, así que lleva el bearer y refresca
 * sola cuando el access vence.
 */
export function collection<T>(path: () => string | undefined): HttpResourceRef<T[]> {
  const base = inject(API_BASE_URL);
  // `undefined` no dispara petición. Devolver cadena vacía sí lo hacía: pedía
  // la raíz del API y traía un 404 por cada carga de quien no tiene el permiso.
  return httpResource<T[]>(
    () => {
      const ruta = path();
      return ruta === undefined ? undefined : `${base}${ruta}`;
    },
    { defaultValue: [] },
  );
}
