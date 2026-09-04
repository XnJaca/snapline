/**
 * Códigos estables de error. **Nunca se traducen ni se renombran**: el cliente
 * ramifica sobre esto, no sobre el mensaje. Ver ADR-0011.
 *
 * Un código nace cuando el cliente necesita distinguirlo para hacer algo distinto.
 * Si solo se muestra el texto, alcanza el genérico del status.
 */
export const ERROR_CODES = [
  // genéricos por status
  'BAD_REQUEST',
  'VALIDATION_FAILED',
  'UNAUTHORIZED',
  'FORBIDDEN',
  'NOT_FOUND',
  'CONFLICT',
  'SERVICE_UNAVAILABLE',
  'INTERNAL_ERROR',

  // auth
  'INVALID_CREDENTIALS',
  'TOKEN_MISSING',
  'TOKEN_INVALID',
  'MEMBERSHIP_INACTIVE',
  'PERMISSION_NOT_DECLARED',
  'PERMISSION_DENIED',

  // proyecto
  'PROJECT_INVALID_TRANSITION',

  // campo
  'TIME_ENTRY_ALREADY_OPEN',
  'TIME_ENTRY_ALREADY_CLOSED',
  'CANNOT_APPROVE_OWN_HOURS',
  'PAY_RATE_MISSING',
  'TIME_ENTRY_STILL_OPEN',
  // Los dos 409 de una decisión. Son distintos porque el cliente hace cosas
  // opuestas con cada uno: MATCHES es benigno —alguien decidió lo mismo— y
  // CONFLICTS es divergencia real, que no se resuelve sola (regla 12).
  'TIME_ENTRY_DECISION_MATCHES',
  'TIME_ENTRY_DECISION_CONFLICTS',

  // contenido y publicación
  'EXIF_NOT_STRIPPED',
  'VISIBILITY_SKIPS_STEP',
  'ASSET_IN_USE',
  'UPLOAD_NOT_READY',
  'MEDIA_ALREADY_UPLOADED',
  'ASSET_NOT_PUBLIC',
  'ALREADY_PUBLISHED',
  // Adjuntar a una nota es elegir entre las fotos de esa obra, no entre todas
  // las de la empresa.
  'ASSET_NOT_IN_PROJECT',

  // comercial
  'ESTIMATE_ALREADY_SENT',
  'ESTIMATE_NOT_ACCEPTED',
  'ESTIMATE_ALREADY_INVOICED',
  'INVOICE_NOT_SENT',
  'INVOICE_VOIDED',
  'PAYMENT_EXCEEDS_BALANCE',

  // almacenamiento
  'STORAGE_NOT_CONFIGURED',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

const BY_STATUS: Record<number, ErrorCode> = {
  400: 'BAD_REQUEST',
  401: 'UNAUTHORIZED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  503: 'SERVICE_UNAVAILABLE',
};

export function defaultCodeFor(status: number): ErrorCode {
  return BY_STATUS[status] ?? 'INTERNAL_ERROR';
}
