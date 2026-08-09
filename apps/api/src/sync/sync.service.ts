import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { HttpException } from '@nestjs/common';
import { runInTransaction } from 'typeorm-transactional';
import { TenantContext } from '../tenant/tenant-context';
import { CustomersService } from '../customers/customers.service';
import { ProjectsService } from '../projects/projects.service';
import { MediaService } from '../media/media.service';
import { TimeEntriesService } from '../time-entries/time-entries.service';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ApiError, FieldError } from '../common/errors/api-error';
import { defaultCodeFor } from '../common/errors/error-codes';
import { CreateCustomerDto } from '../customers/dto/customer.dto';
import { CreateProjectDto } from '../projects/dto/project.dto';
import { RegisterAssetDto } from '../media/dto/media.dto';
import { ClockInDto, ClockOutDto } from '../time-entries/dto/time-entry.dto';
import {
  SyncOperationDto, SyncPullResponseDto, SyncPushDto, SyncPushResponseDto, SyncResultDto,
} from './dto/sync.dto';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Ctor<T> = new (...args: any[]) => T;

const PAYLOAD_DTO = {
  'customer.create': CreateCustomerDto,
  'project.create': CreateProjectDto,
  'media.register': RegisterAssetDto,
  'timeEntry.clockIn': ClockInDto,
  'timeEntry.clockOut': ClockOutDto,
} as const;

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly customers: CustomersService,
    private readonly projects: ProjectsService,
    private readonly media: MediaService,
    private readonly timeEntries: TimeEntriesService,
  ) {}

  /**
   * Aplica la bandeja de salida del dispositivo.
   *
   * Cada operación va en su propia transacción: una que falle no debe tirar abajo
   * las 39 que sí entraron. El dispositivo borra de su bandeja lo que volvió
   * `applied` o `duplicate` y reintenta solo lo demás.
   */
  async push(dto: SyncPushDto, tenant: TenantContext): Promise<SyncPushResponseDto> {
    // En el orden en que ocurrieron: una salida no puede aplicarse antes que su entrada.
    const ordenadas = [...dto.operations].sort(
      (a, b) => Date.parse(a.occurredAt) - Date.parse(b.occurredAt),
    );

    const results: SyncResultDto[] = [];
    for (const op of ordenadas) {
      results.push(await this.applyOne(op, tenant));
    }
    return { results, failed: results.filter((r) => r.status === 'failed').length };
  }

  /**
   * El lote llega como objeto genérico, así que sin esto las operaciones de sync
   * entrarían sin la validación que sí tienen los endpoints sueltos. Es el agujero
   * clásico de un endpoint por lotes.
   */
  private async validatePayload<T extends object>(
    dto: Ctor<T>, payload: Record<string, unknown>, extra: Record<string, unknown>,
  ): Promise<T> {
    const instance = plainToInstance(dto, { ...payload, ...extra }, {
      enableImplicitConversion: true,
    });
    const errors = await validate(instance as object, {
      whitelist: true, forbidNonWhitelisted: false,
    });
    if (errors.length) {
      const details: FieldError[] = errors.map((e) => ({
        field: e.property,
        message: Object.values(e.constraints ?? {}).join(', '),
      }));
      throw ApiError.badRequest('VALIDATION_FAILED', 'El payload de la operación no es válido', details);
    }
    return instance;
  }

  private async applyOne(op: SyncOperationDto, tenant: TenantContext): Promise<SyncResultDto> {
    const ok = (resourceId: string, status: SyncResultDto['status'] = 'applied'): SyncResultDto =>
      ({ clientId: op.clientId, status, resourceId, code: null, message: null });

    try {
      // Ya se aplicó en un intento anterior: la red se cortó después de escribir.
      if (await this.alreadyApplied(op)) return ok(op.targetId, 'duplicate');

      return await runInTransaction(async () => {
        switch (op.type) {
          case 'customer.create': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, { id: op.targetId });
            return ok((await this.customers.create(dto, tenant)).id);
          }
          case 'project.create': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, { id: op.targetId });
            return ok((await this.projects.create(dto, tenant)).id);
          }
          case 'media.register': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, { id: op.targetId });
            return ok((await this.media.register(dto, tenant)).asset.id);
          }
          case 'timeEntry.clockIn': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, {
              id: op.targetId, deviceRecordedAt: op.occurredAt, recordedOffline: true,
            });
            return ok((await this.timeEntries.clockIn(dto, tenant)).id);
          }
          case 'timeEntry.clockOut': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, {
              deviceRecordedAt: op.occurredAt,
            });
            return ok((await this.timeEntries.clockOut(op.targetId, dto, tenant)).id);
          }
        }
      });
    } catch (e) {
      const http = e instanceof HttpException ? e : null;
      const body = http?.getResponse() as { code?: string; message?: string } | undefined;
      // Las excepciones de Nest sin ApiError no traen código: se deriva del status,
      // igual que en el filtro global. Sin esto todo caía en INTERNAL_ERROR y el
      // dispositivo no podía distinguir "no existe" de "se rompió el servidor".
      const code = body?.code ?? (http ? defaultCodeFor(http.getStatus()) : 'INTERNAL_ERROR');

      this.logger.warn(`sync ${op.type} ${op.clientId}: ${code}`);
      return {
        clientId: op.clientId,
        status: 'failed',
        resourceId: null,
        code,
        message: body?.message ?? (http?.message ?? 'No se pudo aplicar'),
      };
    }
  }

  /**
   * Los ids los genera el dispositivo (UUIDv7), así que reintentar un `create`
   * choca contra la clave primaria. Verificarlo antes convierte ese choque en un
   * `duplicate` limpio en vez de un error que el dispositivo reintentaría para siempre.
   */
  private async alreadyApplied(op: SyncOperationDto): Promise<boolean> {
    const TABLAS: Partial<Record<SyncOperationDto['type'], string>> = {
      'customer.create': 'customer',
      'project.create': 'project',
      'media.register': 'media_asset',
      'timeEntry.clockIn': 'time_entry',
    };
    const tabla = TABLAS[op.type];

    if (!tabla) {
      // clockOut no crea nada: ya aplicado significa que el registro está cerrado.
      const [row] = await this.dataSource.query<{ closed: boolean }[]>(
        `SELECT clock_out_at IS NOT NULL AS closed FROM time_entry WHERE id = $1`, [op.targetId]);
      return row?.closed ?? false;
    }

    const [row] = await this.dataSource.query<{ exists: boolean }[]>(
      `SELECT true AS exists FROM ${tabla} WHERE id = $1`, [op.targetId]);
    return Boolean(row);
  }

  /**
   * Cambios desde el cursor. El `serverTime` que devuelve es el cursor siguiente:
   * el reloj del dispositivo no sirve para esto.
   */
  async pull(since: string | undefined, tenant: TenantContext): Promise<SyncPullResponseDto> {
    const [{ now }] = await this.dataSource.query<{ now: string }[]>('SELECT now() AS now');
    const desde = since ?? '-infinity';

    const vivos = async (tabla: string, extra = '', params: unknown[] = []) =>
      this.dataSource.query(
        `SELECT * FROM ${tabla}
         WHERE updated_at > $1::timestamptz AND deleted_at IS NULL ${extra}
         ORDER BY updated_at ASC LIMIT 1000`, [desde, ...params]);

    const borrados = async (tabla: string): Promise<string[]> => {
      const rows = await this.dataSource.query<{ id: string }[]>(
        `SELECT id FROM ${tabla} WHERE updated_at > $1::timestamptz AND deleted_at IS NOT NULL`,
        [desde]);
      return rows.map((r) => r.id);
    };

    // El WORKER solo sincroniza sus proyectos: bajar toda la cartera de clientes
    // al teléfono de cada trabajador sería tan malo como exponerlo por el API.
    // Parametrizado, no interpolado: aunque el id venga de un JWT verificado,
    // armar SQL con concatenación es el hábito que después se cuela con datos ajenos.
    const esWorker = tenant.role === 'WORKER';
    const soloAsignados = esWorker
      ? `AND EXISTS (
           SELECT 1 FROM project_assignment a
           LEFT JOIN crew_member cm ON cm.crew_id = a.crew_id AND cm.deleted_at IS NULL
             AND a.work_date BETWEEN cm.from_date AND coalesce(cm.to_date, a.work_date)
           WHERE a.project_id = project.id AND a.deleted_at IS NULL
             AND (a.membership_id = $2 OR cm.membership_id = $2))`
      : '';
    const workerParam = esWorker ? [tenant.membershipId] : [];

    const [customers, sites, projects, assignments, mediaAssets, timeEntries] = await Promise.all([
      vivos('customer'), vivos('site'), vivos('project', soloAsignados, workerParam),
      vivos('project_assignment'), vivos('media_asset'), vivos('time_entry'),
    ]);

    return {
      serverTime: new Date(now).toISOString(),
      customers, sites, projects, assignments, mediaAssets, timeEntries,
      deleted: {
        customers: await borrados('customer'),
        projects: await borrados('project'),
        mediaAssets: await borrados('media_asset'),
        timeEntries: await borrados('time_entry'),
      },
    };
  }
}
