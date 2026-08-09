import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServiceItem } from '../catalog/entities/service-item.entity';
import { TaxRate } from '../catalog/entities/tax-rate.entity';
import { Estimate } from './entities/estimate.entity';
import { EstimateLine } from './entities/estimate-line.entity';
import { Invoice } from './entities/invoice.entity';
import { InvoiceLine } from './entities/invoice-line.entity';
import { Payment } from './entities/payment.entity';
import { BillingService } from './billing.service';
import { EstimatesController, InvoicesController } from './billing.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Estimate, EstimateLine, Invoice, InvoiceLine, Payment, ServiceItem, TaxRate])],
  controllers: [EstimatesController, InvoicesController],
  providers: [BillingService],
})
export class BillingModule {}
