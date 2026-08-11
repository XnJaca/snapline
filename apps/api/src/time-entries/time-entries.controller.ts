import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { TimeEntriesService } from './time-entries.service';
import { ApproveDto, ClockInDto, ClockOutDto } from './dto/time-entry.dto';
import { TimeEntry } from './entities/time-entry.entity';

@Controller('time-entries')
export class TimeEntriesController {
  constructor(private readonly service: TimeEntriesService) {}

  @RequirePermission('time.read')
  @Get()
  list(
    @CurrentTenant() tenant: TenantContext,
    @Query('projectId') projectId?: string,
  ): Promise<TimeEntry[]> {
    return this.service.list(projectId, tenant);
  }

  @RequirePermission('time.read')
  @Get(':id')
  get(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentTenant() tenant: TenantContext,
  ): Promise<TimeEntry> {
    return this.service.get(id, tenant);
  }

  @RequirePermission('time.clock')
  @Post('clock-in')
  clockIn(@Body() dto: ClockInDto, @CurrentTenant() tenant: TenantContext): Promise<TimeEntry> {
    return this.service.clockIn(dto, tenant);
  }

  @RequirePermission('time.clock')
  @Post(':id/clock-out')
  @HttpCode(200)
  clockOut(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ClockOutDto, @CurrentTenant() tenant: TenantContext): Promise<TimeEntry> {
    return this.service.clockOut(id, dto, tenant);
  }

  @RequirePermission('time.approve')
  @Post(':id/approve')
  @HttpCode(200)
  approve(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ApproveDto, @CurrentTenant() tenant: TenantContext): Promise<TimeEntry> {
    return this.service.approve(id, dto, tenant);
  }

  @RequirePermission('time.approve')
  @Post(':id/reject')
  @HttpCode(200)
  reject(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ApproveDto, @CurrentTenant() tenant: TenantContext): Promise<TimeEntry> {
    return this.service.reject(id, dto, tenant);
  }
}
