import { Body, Controller, Get, HttpCode, Ip, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { BillingService } from './billing.service';
import { AcceptEstimateDto, CreateEstimateDto } from './dto/estimate.dto';
import { CreateInvoiceDto, InvoiceFromEstimateDto, RecordPaymentDto, VoidInvoiceDto } from './dto/invoice.dto';
import { Estimate } from './entities/estimate.entity';
import { Invoice } from './entities/invoice.entity';
import { Payment } from './entities/payment.entity';

@Controller('estimates')
export class EstimatesController {
  constructor(private readonly service: BillingService) {}

  @RequirePermission('billing.read')
  @Get()
  list(): Promise<Estimate[]> {
    return this.service.listEstimates();
  }

  @RequirePermission('billing.read')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string): Promise<Estimate> {
    return this.service.getEstimate(id);
  }

  @RequirePermission('billing.write')
  @Post()
  create(@Body() dto: CreateEstimateDto, @CurrentTenant() tenant: TenantContext): Promise<Estimate> {
    return this.service.createEstimate(dto, tenant);
  }

  @RequirePermission('billing.write')
  @Post(':id/send')
  @HttpCode(200)
  send(@Param('id', ParseUUIDPipe) id: string, @CurrentTenant() tenant: TenantContext): Promise<Estimate> {
    return this.service.sendEstimate(id, tenant);
  }

  @RequirePermission('billing.write')
  @Post(':id/accept')
  @HttpCode(200)
  accept(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AcceptEstimateDto, @Ip() ip: string): Promise<Estimate> {
    return this.service.acceptEstimate(id, dto, ip ?? null);
  }

  @RequirePermission('billing.write')
  @Post(':id/invoice')
  invoice(@Param('id', ParseUUIDPipe) id: string, @Body() dto: InvoiceFromEstimateDto, @CurrentTenant() tenant: TenantContext): Promise<Invoice> {
    return this.service.invoiceFromEstimate(id, dto, tenant);
  }
}

@Controller('invoices')
export class InvoicesController {
  constructor(private readonly service: BillingService) {}

  @RequirePermission('billing.read')
  @Get()
  list(): Promise<Invoice[]> {
    return this.service.listInvoices();
  }

  @RequirePermission('billing.read')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string): Promise<Invoice> {
    return this.service.getInvoice(id);
  }

  @RequirePermission('billing.write')
  @Post()
  create(@Body() dto: CreateInvoiceDto, @CurrentTenant() tenant: TenantContext): Promise<Invoice> {
    return this.service.createInvoice(dto, tenant);
  }

  @RequirePermission('billing.write')
  @Post(':id/send')
  @HttpCode(200)
  send(@Param('id', ParseUUIDPipe) id: string, @CurrentTenant() tenant: TenantContext): Promise<Invoice> {
    return this.service.sendInvoice(id, tenant);
  }

  @RequirePermission('billing.write')
  @Post(':id/payments')
  recordPayment(@Param('id', ParseUUIDPipe) id: string, @Body() dto: RecordPaymentDto, @CurrentTenant() tenant: TenantContext): Promise<Invoice> {
    return this.service.recordPayment(id, dto, tenant);
  }

  @RequirePermission('billing.read')
  @Get(':id/payments')
  payments(@Param('id', ParseUUIDPipe) id: string): Promise<Payment[]> {
    return this.service.listPayments(id);
  }

  @RequirePermission('billing.write')
  @Post(':id/void')
  @HttpCode(200)
  voidInvoice(@Param('id', ParseUUIDPipe) id: string, @Body() dto: VoidInvoiceDto): Promise<Invoice> {
    return this.service.voidInvoice(id, dto);
  }
}
