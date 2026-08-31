import type { components } from '@snapline/contracts';

// Del contrato, no copiados a mano: `openapi.json` es la fuente (ADR-0007).
export type WebAuthResult = components['schemas']['WebAuthResultDto'];
export type SessionUser = components['schemas']['AuthUserDto'];
export type SessionMembership = components['schemas']['AuthMembershipDto'];

/**
 * `offline` no es lo mismo que `anonymous`: el refresh que falla por red deja la
 * sesión en duda, y mandar a login haría creer que venció.
 */
export type SessionStatus = 'unknown' | 'authenticated' | 'anonymous' | 'offline';
