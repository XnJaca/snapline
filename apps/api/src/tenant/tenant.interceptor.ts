import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Observable } from 'rxjs';
import { from, switchMap } from 'rxjs';
import { runOnTransactionComplete, runInTransaction } from 'typeorm-transactional';
import { tenantStorage, TenantContext } from './tenant-context';

// Abre una transacción por request y setea app.company_id ahí. SET LOCAL no se
// filtra entre requests que compartan conexión del pool.
@Injectable()
export class TenantContextInterceptor implements NestInterceptor {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<{ tenant?: TenantContext }>();
    const tenant = req.tenant;

    // Rutas públicas todavía no tienen tenant.
    if (!tenant) return next.handle();

    return from(
      runInTransaction(async () => {
        await this.dataSource.query('SELECT set_config($1, $2, true)', [
          'app.company_id',
          tenant.companyId,
        ]);
        return tenantStorage.run(tenant, () => next.handle().toPromise());
      }),
    ).pipe(switchMap((result) => from(Promise.resolve(result))));
  }
}
