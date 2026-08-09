import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { runInTransaction } from 'typeorm-transactional';
import { tenantStorage, TenantContext } from './tenant-context';

@Injectable()
export class TenantService {
  private readonly logger = new Logger(TenantService.name);

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

  /**
   * **No bypassa RLS.** El rol de runtime no puede saltársela: es el punto de
   * ADR-0006. Esto solo marca y audita trabajo que corre sin contexto de tenant,
   * y solo sirve para tablas sin `company_id`.
   *
   * Para leer una tabla con RLS sin contexto —resolver un login, canjear el token
   * del portal, servir el portafolio público— hace falta una función
   * `SECURITY DEFINER` acotada a esa consulta. Hay tres en el sistema y no debería
   * haber una cuarta sin discutirlo.
   */
  async runWithoutTenant<T>(reason: string, work: () => Promise<T> | T): Promise<T> {
    this.logger.warn(`sin contexto de tenant: ${reason}`);
    return work();
  }
}
