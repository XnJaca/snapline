import { HttpErrorResponse } from '@angular/common/http';

/**
 * Un fallo de transporte y uno de credenciales no se muestran igual, y sin esta
 * distinción se confunden: sin red no hay respuesta HTTP, así que tampoco hay
 * `code` de ADR-0011 que traducir.
 */
export type ApiFailure =
  | { kind: 'network' }
  | { kind: 'http'; status: number; code: string; message: string };

export function toApiFailure(error: unknown): ApiFailure {
  if (!(error instanceof HttpErrorResponse)) return { kind: 'network' };

  // El navegador reporta 0 cuando no hubo respuesta: DNS, servidor caído, CORS.
  if (error.status === 0) return { kind: 'network' };

  const body = error.error as { code?: string; message?: string } | null;
  return {
    kind: 'http',
    status: error.status,
    code: body?.code ?? 'INTERNAL_ERROR',
    message: body?.message ?? error.message,
  };
}

export function isNetworkFailure(error: unknown): boolean {
  return toApiFailure(error).kind === 'network';
}
