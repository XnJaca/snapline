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

  // contenido y publicación
  'PHOTO_RELEASE_REQUIRED',
  'EXIF_NOT_STRIPPED',
  'UPLOAD_NOT_READY',
  'MEDIA_ALREADY_UPLOADED',
  'ASSET_NOT_PUBLIC',
  'ALREADY_PUBLISHED',

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
