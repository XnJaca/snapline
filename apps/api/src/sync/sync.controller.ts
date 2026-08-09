import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { ApiOkResponse } from '@nestjs/swagger';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { SyncService } from './sync.service';
import { SyncPullQueryDto, SyncPullResponseDto, SyncPushDto, SyncPushResponseDto } from './dto/sync.dto';

@Controller('sync')
export class SyncController {
  constructor(private readonly service: SyncService) {}

  @RequirePermission('projects.read')
  @Get()
  @ApiOkResponse({ type: SyncPullResponseDto })
  pull(@Query() q: SyncPullQueryDto, @CurrentTenant() tenant: TenantContext): Promise<SyncPullResponseDto> {
    return this.service.pull(q.since, tenant);
  }

  @RequirePermission('time.clock')
  @Post()
  @HttpCode(200)
  @ApiOkResponse({ type: SyncPushResponseDto })
  push(@Body() dto: SyncPushDto, @CurrentTenant() tenant: TenantContext): Promise<SyncPushResponseDto> {
    return this.service.push(dto, tenant);
  }
}
