import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityTarget, ObjectLiteral } from 'typeorm';
import { HttpException } from '@nestjs/common';
import { runInTransaction } from 'typeorm-transactional';
import { TenantContext } from '../tenant/tenant-context';
import { Customer } from '../customers/entities/customer.entity';
import { Site } from '../customers/entities/site.entity';
import { Project } from '../projects/entities/project.entity';
import { ProjectAssignment } from '../projects/entities/project-assignment.entity';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { TimeEntry } from '../time-entries/entities/time-entry.entity';
import { Crew } from '../crews/entities/crew.entity';
import { CrewMember } from '../crews/entities/crew-member.entity';
import { CustomersService } from '../customers/customers.service';
import { ProjectsService } from '../projects/projects.service';
import { MediaService } from '../media/media.service';
import { TimeEntriesService } from '../time-entries/time-entries.service';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ApiError, FieldError } from '../common/errors/api-error';
import { defaultCodeFor } from '../common/errors/error-codes';
import { CreateCustomerDto, UpdateCustomerDto, UpdateSiteDto } from '../customers/dto/customer.dto';
import { CreateProjectDto, UpdateProjectDto } from '../projects/dto/project.dto';
import { roleHasPermission } from '../auth/permissions';
import { newId } from '../common/entities/base.entity';
import { RegisterAssetDto } from '../media/dto/media.dto';
import { ClockInDto, ClockOutDto } from '../time-entries/dto/time-entry.dto';
import {
  OPERATION_PERMISSION,
  SyncOperationDto, SyncOperationType, SyncPullResponseDto, SyncPushDto, SyncPushResponseDto,
  SyncResultDto, SyncSiteCreateDto,
  SyncPersonDto,
} from './dto/sync.dto';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Ctor<T> = new (...args: any[]) => T;

const PAYLOAD_DTO = {
  'customer.create': CreateCustomerDto,
  'customer.update': UpdateCustomerDto,
  'site.create': SyncSiteCreateDto,
  'site.update': UpdateSiteDto,
  'project.create': CreateProjectDto,
  'project.update': UpdateProjectDto,
  'media.register': RegisterAssetDto,
  'timeEntry.clockIn': ClockInDto,
  'timeEntry.clockOut': ClockOutDto,
  // El `satisfies` es el que obliga: una operación agregada a `SYNC_OPERATIONS`
  // sin su DTO de payload no compila, en vez de entrar al lote sin validar.
} as const satisfies Record<SyncOperationType, Ctor<object>>;

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
      // El endpoint entra con `time.clock`, pero adentro del lote viajan
      // operaciones que por la puerta REST piden mucho más. Sin esto un WORKER
      // daba de alta clientes y proyectos sin tener `customers.write` (regla 7).
      if (!roleHasPermission(tenant.role, OPERATION_PERMISSION[op.type])) {
        this.logger.warn(`sync ${op.type} ${op.clientId}: sin permiso para ${tenant.role}`);
        return {
          clientId: op.clientId,
          status: 'failed',
          resourceId: null,
          code: 'FORBIDDEN',
          message: 'El rol de la sesión no puede aplicar esta operación',
        };
      }

      // Ya se aplicó en un intento anterior: la red se cortó después de escribir.
      const yaAplicada = await this.alreadyApplied(op, tenant);
      if (yaAplicada) return ok(yaAplicada, 'duplicate');

      return await runInTransaction(async () => {
        const resultado = await this.aplicar(op, tenant, ok);
        // En la misma transacción que la operación: si algo falla, no queda
        // registrada como aplicada y el reintento la vuelve a intentar.
        await this.registrar(op, tenant, resultado.resourceId);
        return resultado;
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

  private async aplicar(
    op: SyncOperationDto,
    tenant: TenantContext,
    ok: (resourceId: string, status?: SyncResultDto['status']) => SyncResultDto,
  ): Promise<SyncResultDto> {
    switch (op.type) {
          case 'customer.create': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, { id: op.targetId });
            return ok((await this.customers.create(dto, tenant)).id);
          }
          case 'customer.update': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, {});
            return ok((await this.customers.update(op.targetId, dto)).id);
          }
          // `targetId` es el id de la propiedad; de qué cliente cuelga viaja en
          // el payload, porque una propiedad no existe suelta.
          case 'site.create': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, { id: op.targetId });
            const { customerId, ...site } = dto;
            return ok((await this.customers.addSite(customerId, site, tenant)).id);
          }
          // Sin `customerId`: una propiedad no cambia de cliente, y el
          // dispositivo solo tiene el id de la propiedad que está corrigiendo.
          case 'site.update': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, {});
            return ok((await this.customers.updateSite(op.targetId, dto)).id);
          }
          case 'project.create': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, { id: op.targetId });
            return ok((await this.projects.create(dto, tenant)).id);
          }
          // Llega de un dispositivo que pudo estar días sin señal: si mientras
          // tanto la obra avanzó, la transición retrocedente se descarta en vez
          // de fallar, o se quedaría en su bandeja para siempre.
          case 'project.update': {
            const dto = await this.validatePayload(PAYLOAD_DTO[op.type], op.payload, {});
            return ok(
              (await this.projects.update(op.targetId, dto, { fromOutbox: true })).id,
            );
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
  }

  /**
   * El id del recurso si esta operación ya se aplicó, `null` si es nueva.
   *
   * La clave es el `client_id` que generó el dispositivo, no la existencia del
   * recurso: en un `update` el recurso siempre existe, así que ese criterio
   * habría devuelto `duplicate` sin aplicar nunca la corrección.
   */
  private async alreadyApplied(
    op: SyncOperationDto, tenant: TenantContext,
  ): Promise<string | null> {
    const [row] = await this.dataSource.query<{ resource_id: string | null }[]>(
      `SELECT resource_id FROM sync_operation WHERE company_id = $1 AND client_id = $2`,
      [tenant.companyId, op.clientId],
    );
    if (!row) return null;
    return row.resource_id ?? op.targetId;
  }

  /**
   * `ON CONFLICT DO NOTHING` por si dos lotes con la misma clave entran a la vez:
   * el índice único es la garantía real, esto solo evita que reviente.
   */
  private async registrar(
    op: SyncOperationDto, tenant: TenantContext, resourceId: string | null,
  ): Promise<void> {
    await this.dataSource.query(
      `INSERT INTO sync_operation (id, company_id, client_id, type, target_id, resource_id)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (company_id, client_id) DO NOTHING`,
      [newId(), tenant.companyId, op.clientId, op.type, op.targetId, resourceId],
    );
  }

  /**
   * Cambios desde el cursor. El `serverTime` que devuelve es el cursor siguiente:
   * el reloj del dispositivo no sirve para esto.
   */
  async pull(since: string | undefined, tenant: TenantContext): Promise<SyncPullResponseDto> {
    const [{ now }] = await this.dataSource.query<{ now: string }[]>('SELECT now() AS now');
    const desde = since ?? '-infinity';

    /**
     * Por repositorio y no con `SELECT *`: la consulta cruda devuelve las
     * columnas como están en la base —`display_name`— y el contrato promete
     * `displayName`. Un contrato que miente es peor que uno sin tipos: el
     * cliente parsea, no encuentra nada y no falla.
     */
    const vivos = async <T extends ObjectLiteral>(
      entity: EntityTarget<T>, alias: string, extra?: string, params: ObjectLiteral = {},
    ): Promise<T[]> => {
      const qb = this.dataSource.getRepository(entity).createQueryBuilder(alias)
        .where(`${alias}.updatedAt > :desde::timestamptz`, { desde })
        .andWhere(`${alias}.deletedAt IS NULL`)
        .orderBy(`${alias}.updatedAt`, 'ASC')
        .limit(1000);
      if (extra) qb.andWhere(extra, params);
      return qb.getMany();
    };

    const borrados = async (tabla: string): Promise<string[]> => {
      const rows = await this.dataSource.query<{ id: string }[]>(
        `SELECT id FROM ${tabla} WHERE updated_at > $1::timestamptz AND deleted_at IS NOT NULL`,
        [desde]);
      return rows.map((r) => r.id);
    };

    // Los roles de campo solo sincronizan lo de sus obras.
    //
    // El endpoint entra con `projects.read`, que WORKER y FOREMAN tienen, así
    // que el scope por rol **es** el control de acceso de lo que baja: sin él
    // el pull entrega lo que la puerta REST le niega. Estuvo acotado solo para
    // WORKER, y un FOREMAN se bajaba la cartera completa de clientes y las
    // horas de toda la empresa.
    //
    // Lo que baja queda en disco: el router puede esconder una pantalla, pero un
    // dispositivo perdido o robado ya tiene los datos.
    const esWorker = tenant.role === 'WORKER';
    const acotado = esWorker || tenant.role === 'FOREMAN';
    const workerParam = acotado ? { membershipId: tenant.membershipId } : {};

    /// Tiene asignación vigente en ese proyecto, directa o por su cuadrilla.
    const asignadoA = (projectId: string) => `EXISTS (
           SELECT 1 FROM project_assignment a
           LEFT JOIN crew_member cm ON cm.crew_id = a.crew_id AND cm.deleted_at IS NULL
             AND a.work_date BETWEEN cm.from_date AND coalesce(cm.to_date, a.work_date)
           WHERE a.project_id = ${projectId} AND a.deleted_at IS NULL
             AND (a.membership_id = :membershipId OR cm.membership_id = :membershipId))`;

    /// El cliente y la propiedad bajan solo si cuelga de ellos una obra asignada.
    const deSusObras = (fk: string, columna: string) => `EXISTS (
           SELECT 1 FROM project p
           WHERE p.${columna} = ${fk} AND p.deleted_at IS NULL
             AND ${asignadoA('p.id')})`;

    const soloSi = (expr: string) => (acotado ? expr : undefined);

    /// La cuadrilla es visible si la persona la lidera o la integra.
    const cuadrillaVisible = (crewId: string) => `(
           EXISTS (SELECT 1 FROM crew cx WHERE cx.id = ${crewId} AND cx.deleted_at IS NULL
                     AND cx.foreman_membership_id = :membershipId)
           OR EXISTS (SELECT 1 FROM crew_member cmx WHERE cmx.crew_id = ${crewId}
                        AND cmx.membership_id = :membershipId AND cmx.deleted_at IS NULL))`;

    const [customers, sites, projects, assignments, mediaAssets, timeEntries, crews, crewMembers] = await Promise.all([
      vivos(Customer, 'customer', soloSi(deSusObras('customer.id', 'customer_id')), workerParam),
      vivos(Site, 'site', soloSi(deSusObras('site.id', 'site_id')), workerParam),
      vivos(Project, 'project', soloSi(asignadoA('project.id')), workerParam),
      // El WORKER recibe las suyas; el FOREMAN, todas las de sus obras — sin
      // eso no puede saber quién tenía que estar hoy.
      vivos(
        ProjectAssignment,
        'project_assignment',
        esWorker
          ? `(project_assignment.membership_id = :membershipId
             OR EXISTS (SELECT 1 FROM crew_member cm
                        WHERE cm.crew_id = project_assignment.crew_id
                          AND cm.membership_id = :membershipId
                          AND cm.deleted_at IS NULL))`
          : soloSi(asignadoA('project_assignment.project_id')),
        workerParam,
      ),
      vivos(MediaAsset, 'media_asset', soloSi(asignadoA('media_asset.project_id')), workerParam),
      // El WORKER solo sus horas; el FOREMAN las de sus obras, que es a quién
      // les marca y les revisa el día. Las coordenadas de cada marcaje bajan
      // con esto — la tarifa no: va oculta en la entity, para todos.
      vivos(
        TimeEntry,
        'time_entry',
        esWorker
          ? 'time_entry.membership_id = :membershipId'
          : soloSi(asignadoA('time_entry.project_id')),
        workerParam,
      ),
      // Las cuadrillas que lidera o integra; para la oficina, todas.
      vivos(Crew, 'crew', soloSi(cuadrillaVisible('crew.id')), workerParam),
      vivos(CrewMember, 'crew_member', soloSi(cuadrillaVisible('crew_member.crew_id')), workerParam),
    ]);

    const people = await this.gente(desde, acotado ? tenant.membershipId : null);

    return {
      serverTime: new Date(now).toISOString(),
      customers, sites, projects, assignments, mediaAssets, timeEntries,
      crews, crewMembers, people,
      // Las seis colecciones que el pull trae vivas emiten también sus bajas: si
      // una falta, ese borrado nunca llega al dispositivo y la fila queda para
      // siempre en la base local (regla 20).
      deleted: {
        customers: await borrados('customer'),
        sites: await borrados('site'),
        projects: await borrados('project'),
        assignments: await borrados('project_assignment'),
        mediaAssets: await borrados('media_asset'),
        timeEntries: await borrados('time_entry'),
        crews: await borrados('crew'),
        crewMembers: await borrados('crew_member'),
        // La persona es una proyección de la membresía: su baja viaja acá.
        people: await borrados('membership'),
      },
    };
  }

  /**
   * La identidad de cada membresía, para mostrar personas y no UUIDs.
   *
   * Con alcance: los roles de campo reciben solo a la gente de sus cuadrillas y
   * de sus obras, y a sí mismos. El nombre sale de `app_user`, así que el
   * cursor mira las dos tablas — un nombre corregido tiene que llegar aunque la
   * membresía no haya cambiado.
   */
  private async gente(desde: string, membershipId: string | null): Promise<SyncPersonDto[]> {
    const alcance = membershipId === null ? '' : `
      AND (m.id = $2
        OR EXISTS (SELECT 1 FROM crew c
                   LEFT JOIN crew_member cm ON cm.crew_id = c.id AND cm.deleted_at IS NULL
                   WHERE c.deleted_at IS NULL
                     AND (c.foreman_membership_id = $2
                          OR EXISTS (SELECT 1 FROM crew_member yo WHERE yo.crew_id = c.id
                                       AND yo.membership_id = $2 AND yo.deleted_at IS NULL))
                     AND (cm.membership_id = m.id OR c.foreman_membership_id = m.id))
        OR EXISTS (SELECT 1 FROM project_assignment a
                   WHERE a.deleted_at IS NULL AND a.membership_id = m.id
                     AND EXISTS (SELECT 1 FROM project_assignment mia
                                 LEFT JOIN crew_member cmx ON cmx.crew_id = mia.crew_id
                                   AND cmx.deleted_at IS NULL
                                 WHERE mia.project_id = a.project_id AND mia.deleted_at IS NULL
                                   AND (mia.membership_id = $2 OR cmx.membership_id = $2))))`;

    const params: unknown[] = membershipId === null ? [desde] : [desde, membershipId];
    return (await this.dataSource.query(
      `SELECT m.id AS "membershipId", u.name AS "name", m.role AS "role"
       FROM membership m
       JOIN app_user u ON u.id = m.user_id
       WHERE m.deleted_at IS NULL AND m.status = 'ACTIVE'
         AND (m.updated_at > $1::timestamptz OR u.updated_at > $1::timestamptz)
         ${alcance}
       ORDER BY u.name ASC`,
      params,
    )) as SyncPersonDto[];
  }
}
