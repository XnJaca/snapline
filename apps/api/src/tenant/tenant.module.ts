import { Global, Module } from '@nestjs/common';
import { TenantService } from './tenant.service';
import { TenantContextInterceptor } from './tenant.interceptor';

@Global()
@Module({
  providers: [TenantService, TenantContextInterceptor],
  exports: [TenantService, TenantContextInterceptor],
})
export class TenantModule {}
