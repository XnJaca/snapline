import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { CatalogService } from './catalog.service';
import { CreateServiceItemDto, UpdateServiceItemDto } from './dto/service-item.dto';
import { ServiceItem } from './entities/service-item.entity';

@Controller('service-items')
export class CatalogController {
  constructor(private readonly service: CatalogService) {}

  @RequirePermission('catalog.read')
  @Get()
  list(@Query('includeInactive') includeInactive?: string): Promise<ServiceItem[]> {
    return this.service.list(includeInactive === 'true');
  }

  @RequirePermission('catalog.read')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string): Promise<ServiceItem> {
    return this.service.get(id);
  }

  @RequirePermission('catalog.write')
  @Post()
  create(@Body() dto: CreateServiceItemDto, @CurrentTenant() tenant: TenantContext): Promise<ServiceItem> {
    return this.service.create(dto, tenant);
  }

  @RequirePermission('catalog.write')
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateServiceItemDto): Promise<ServiceItem> {
    return this.service.update(id, dto);
  }

  @RequirePermission('catalog.write')
  @Delete(':id')
  @HttpCode(200)
  deactivate(@Param('id', ParseUUIDPipe) id: string): Promise<ServiceItem> {
    return this.service.deactivate(id);
  }
}
