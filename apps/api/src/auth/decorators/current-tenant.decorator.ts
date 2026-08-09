import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { TenantContext } from '../../tenant/tenant-context';

export const CurrentTenant = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): TenantContext =>
    ctx.switchToHttp().getRequest<{ tenant: TenantContext }>().tenant,
);
