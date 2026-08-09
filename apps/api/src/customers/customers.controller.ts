import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { CustomersService } from './customers.service';
import { CreateCustomerDto, SiteInputDto, UpdateCustomerDto } from './dto/customer.dto';
import { Customer } from './entities/customer.entity';
import { Site } from './entities/site.entity';

@Controller('customers')
export class CustomersController {
  constructor(private readonly service: CustomersService) {}

  @RequirePermission('customers.read')
  @Get()
  list(): Promise<Customer[]> {
    return this.service.list();
  }

  @RequirePermission('customers.read')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string): Promise<Customer> {
    return this.service.get(id);
  }

  @RequirePermission('customers.write')
  @Post()
  create(@Body() dto: CreateCustomerDto, @CurrentTenant() tenant: TenantContext): Promise<Customer> {
    return this.service.create(dto, tenant);
  }

  @RequirePermission('customers.write')
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCustomerDto): Promise<Customer> {
    return this.service.update(id, dto);
  }

  @RequirePermission('customers.write')
  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.service.remove(id);
  }

  @RequirePermission('customers.read')
  @Get(':id/sites')
  listSites(@Param('id', ParseUUIDPipe) id: string): Promise<Site[]> {
    return this.service.listSites(id);
  }

  @RequirePermission('customers.write')
  @Post(':id/sites')
  addSite(@Param('id', ParseUUIDPipe) id: string, @Body() dto: SiteInputDto, @CurrentTenant() tenant: TenantContext): Promise<Site> {
    return this.service.addSite(id, dto, tenant);
  }

  @RequirePermission('customers.write')
  @Post(':id/photo-release')
  @HttpCode(200)
  grantRelease(@Param('id', ParseUUIDPipe) id: string, @Body() body: { granted: boolean; documentId?: string }): Promise<Customer> {
    return this.service.setPhotoRelease(id, body.granted, body.documentId);
  }
}
