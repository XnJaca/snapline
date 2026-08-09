import { MembershipRole } from './entities/membership.entity';

// Default deny: un endpoint sin @RequirePermission responde 403 (regla 7).
// El cliente final no aparece acá — entra por token, con su propio camino.
export const PERMISSIONS = {
  'customers.read': ['OWNER', 'ADMIN', 'ACCOUNTANT'],
  'customers.write': ['OWNER', 'ADMIN'],

  'projects.read': ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'],
  'projects.write': ['OWNER', 'ADMIN'],
  'projects.publish': ['OWNER', 'ADMIN'],

  'crews.read': ['OWNER', 'ADMIN', 'FOREMAN'],
  'crews.write': ['OWNER', 'ADMIN'],

  'time.clock': ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER'],
  'time.read': ['OWNER', 'ADMIN', 'FOREMAN', 'ACCOUNTANT'],
  // Nadie aprueba sus propias horas; el servicio lo verifica además del rol.
  'time.approve': ['OWNER', 'ADMIN'],

  'media.capture': ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER'],
  'media.read': ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER'],
  'media.visibility': ['OWNER', 'ADMIN'],

  'catalog.read': ['OWNER', 'ADMIN', 'ACCOUNTANT'],
  'catalog.write': ['OWNER', 'ADMIN'],

  'billing.read': ['OWNER', 'ADMIN', 'ACCOUNTANT'],
  'billing.write': ['OWNER', 'ADMIN'],

  'reports.read': ['OWNER', 'ADMIN', 'ACCOUNTANT'],
  'members.manage': ['OWNER', 'ADMIN'],

  // Cambiar lo propio: el idioma de la persona. Todos los roles, porque cada
  // uno solo puede tocar su propio usuario — el servicio usa el id de la sesión
  // y nunca uno recibido del cliente.
  'profile.write': ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'],
} as const satisfies Record<string, readonly MembershipRole[]>;

export type Permission = keyof typeof PERMISSIONS;

export function roleHasPermission(role: MembershipRole, permission: Permission): boolean {
  return (PERMISSIONS[permission] as readonly MembershipRole[]).includes(role);
}
