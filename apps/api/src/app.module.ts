import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { DataSource } from 'typeorm';
import { addTransactionalDataSource, getDataSourceByName } from 'typeorm-transactional';
import { databaseConfig } from './config/database.config';
import { TenantModule } from './tenant/tenant.module';
import { StorageModule } from './storage/storage.module';
import { throttleConfig } from './common/throttle/throttle.config';
import { TenantContextInterceptor } from './tenant/tenant.interceptor';
import { AuthModule } from './auth/auth.module';
import { AuthGuard } from './auth/guards/auth.guard';
import { CustomersModule } from './customers/customers.module';
import { ProjectsModule } from './projects/projects.module';
import { MediaModule } from './media/media.module';
import { TimeEntriesModule } from './time-entries/time-entries.module';
import { CatalogModule } from './catalog/catalog.module';
import { CrewsModule } from './crews/crews.module';
import { BillingModule } from './billing/billing.module';
import { ReportsModule } from './reports/reports.module';
import { PublishingModule } from './publishing/publishing.module';
import { ClientPortalModule } from './client-portal/client-portal.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot(throttleConfig),
    TypeOrmModule.forRootAsync({
      useFactory: databaseConfig,
      // El reintento de TypeORM vuelve a llamar la factory; sin esta guarda
      // addTransactionalDataSource tira "already added" y enmascara el error real.
      dataSourceFactory: async (options) => {
        if (!options) throw new Error('Falta configuración de base de datos');
        return getDataSourceByName('default') ?? addTransactionalDataSource(new DataSource(options));
      },
    }),
    TenantModule,
    StorageModule,
    AuthModule,
    CustomersModule,
    ProjectsModule,
    MediaModule,
    TimeEntriesModule,
    CatalogModule,
    CrewsModule,
    BillingModule,
    ReportsModule,
    PublishingModule,
    ClientPortalModule,
  ],
  providers: [
    // El throttler va primero: cortar antes de tocar la base es el punto.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // Después: el guard resuelve el tenant, el interceptor lo aplica al GUC.
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
})
export class AppModule {}
