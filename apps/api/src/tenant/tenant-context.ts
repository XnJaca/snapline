import { AsyncLocalStorage } from 'node:async_hooks';
import { MembershipRole } from '../auth/entities/membership.entity';

export interface TenantContext {
  companyId: string;
  membershipId: string;
  userId: string;
  role: MembershipRole;
}

export const tenantStorage = new AsyncLocalStorage<TenantContext>();

export function currentTenant(): TenantContext | undefined {
  return tenantStorage.getStore();
}

export function requireTenant(): TenantContext {
  const ctx = tenantStorage.getStore();
  if (!ctx) {
    throw new Error(
      'Sin contexto de tenant. Toda operación de request pasa por TenantContextInterceptor; ' +
        'fuera de request usar TenantService.runUnscoped().',
    );
  }
  return ctx;
}
