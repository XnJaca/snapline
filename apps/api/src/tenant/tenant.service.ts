import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { runInTransaction } from 'typeorm-transactional';
import { tenantStorage, TenantContext } from './tenant-context';

@Injectable()
export class TenantService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  // Para trabajo fuera de un request: crons, listeners, seeds.
  async runAs<T>(tenant: TenantContext, work: () => Promise<T>): Promise<T> {
    return runInTransaction(async () => {
      await this.dataSource.query('SELECT set_config($1, $2, true)', [
        'app.company_id',
        tenant.companyId,
      ]);
      return tenantStorage.run(tenant, work);
    });
  }

  // Bypass auditable. Grep-able a propósito: la lista debe ser corta y justificable.
  async runUnscoped<T>(reason: string, work: () => Promise<T>): Promise<T> {
    // eslint-disable-next-line no-console
    console.warn(`[tenant] bypass_rls: ${reason}`);
    return work();
  }
}
