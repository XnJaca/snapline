import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository, SelectQueryBuilder } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext, currentTenant } from '../tenant/tenant-context';
import { Site } from '../customers/entities/site.entity';
import { Project, ProjectStatus } from './entities/project.entity';
import { ProjectAssignment } from './entities/project-assignment.entity';
import { ProjectStatusChange } from './entities/project-status-change.entity';
import { ProjectUpdate } from './entities/project-update.entity';
import { ProjectUpdateAsset } from './entities/project-update-asset.entity';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { MediaService } from '../media/media.service';
import { AssignCrewDto, CreateProjectDto, CreateProjectUpdateDto, UpdateProjectDto } from './dto/project.dto';
import { canTransition, shouldDiscardStatus } from './project-status';

@Injectable()
export class ProjectsService {
  constructor(
    @InjectRepository(Project) private readonly projects: Repository<Project>,
    @InjectRepository(ProjectAssignment) private readonly assignments: Repository<ProjectAssignment>,
    @InjectRepository(Site) private readonly sites: Repository<Site>,
    @InjectRepository(ProjectStatusChange)
    private readonly statusChanges: Repository<ProjectStatusChange>,
    @InjectRepository(ProjectUpdate) private readonly updates: Repository<ProjectUpdate>,
    @InjectRepository(ProjectUpdateAsset)
    private readonly updateAssets: Repository<ProjectUpdateAsset>,
    @InjectRepository(MediaAsset) private readonly assets: Repository<MediaAsset>,
    private readonly media: MediaService,
  ) {}

  /**
   * El WORKER solo ve donde tiene asignación: directa, o por la cuadrilla a la
   * que pertenecía en esa fecha. RLS aísla entre empresas; esto acota adentro,
   * para que un trabajador no enumere todos los clientes y direcciones.
   */
  list(tenant?: TenantContext): Promise<Project[]> {
    const q = this.projects.createQueryBuilder('p')
      .leftJoinAndSelect('p.customer', 'customer')
      .leftJoinAndSelect('p.site', 'site')
      .where('p.deletedAt IS NULL')
      .orderBy('p.createdAt', 'DESC');

    if (tenant?.role === 'WORKER') this.restrictToAssigned(q, tenant.membershipId);
    return q.getMany();
  }

  async get(id: string, tenant?: TenantContext): Promise<Project> {
    const q = this.projects.createQueryBuilder('p')
      .leftJoinAndSelect('p.customer', 'customer')
      .leftJoinAndSelect('p.site', 'site')
      .where('p.id = :id', { id })
      .andWhere('p.deletedAt IS NULL');

    if (tenant?.role === 'WORKER') this.restrictToAssigned(q, tenant.membershipId);

    const found = await q.getOne();
    // Mismo 404 que si no existiera: no se confirma la existencia de un proyecto
    // al que no se tiene acceso.
    if (!found) throw ApiError.notFound('NOT_FOUND', 'Proyecto no encontrado');
    return found;
  }

  private restrictToAssigned(q: SelectQueryBuilder<Project>, membershipId: string): void {
    q.andWhere(
      `EXISTS (
         SELECT 1 FROM project_assignment a
         LEFT JOIN crew_member cm
           ON cm.crew_id = a.crew_id
          AND cm.deleted_at IS NULL
          AND a.work_date BETWEEN cm.from_date AND coalesce(cm.to_date, a.work_date)
         WHERE a.project_id = p.id
           AND a.deleted_at IS NULL
           AND (a.membership_id = :mid OR cm.membership_id = :mid)
       )`,
      { mid: membershipId },
    );
  }

  @Transactional()
  async create(dto: CreateProjectDto, tenant: TenantContext): Promise<Project> {
    const id = dto.id ?? newId();
    if (dto.id && (await this.projects.findOne({ where: { id } }))) {
      throw new ConflictException('Ya existe un proyecto con ese id');
    }
    // El sitio tiene que ser del mismo cliente: no se cruzan.
    const site = await this.sites.findOne({ where: { id: dto.siteId, deletedAt: IsNull() } });
    if (!site) throw new NotFoundException('Sitio no encontrado');
    if (site.customerId !== dto.customerId) {
      throw new BadRequestException('El sitio no pertenece a ese cliente');
    }

    const project = this.projects.create({
      id,
      companyId: tenant.companyId,
      customer: { id: dto.customerId } as Project['customer'],
      site: { id: dto.siteId } as Project['site'],
      name: dto.name,
      description: dto.description ?? null,
      serviceType: dto.serviceType ?? null,
      status: dto.status ?? 'LEAD',
      clientVisibilityMode: dto.clientVisibilityMode ?? 'STAGES',
      startDate: dto.startDate ?? null,
      targetEndDate: dto.targetEndDate ?? null,
      actualEndDate: null,
      publishedAt: null,
      deletedAt: null,
    });
    await this.projects.save(project);
    // Toda obra nace con su hito de origen: sin él, el hilo de una obra nueva
    // no tendría de dónde sacar el estado de partida de un cambio pendiente.
    await this.registrarHito(project, null, project.status, tenant.membershipId);
    return this.get(id);
  }

  /**
   * `fromOutbox` lo pone la bandeja de salida, nunca la puerta REST.
   *
   * Por la bandeja, un cambio de estado que ya no es válido **se ignora y no
   * falla**: el dispositivo mandó lo que era válido desde el estado que conocía y
   * no puede saber que la obra avanzó, así que si respondiéramos error la
   * operación se quedaría en su cola reintentándose para siempre. Se aplica el
   * resto de los campos y el estado se ignora. Es lo único de `project` que no es
   * última escritura gana.
   *
   * Por REST falla, porque ahí hay alguien mirando la pantalla que puede corregir.
   */
  @Transactional()
  async update(
    id: string,
    dto: UpdateProjectDto,
    opciones?: { fromOutbox?: boolean; occurredAt?: string },
  ): Promise<Project> {
    const actual = await this.get(id);
    const cambios: UpdateProjectDto = { ...dto };

    if (cambios.status && !canTransition(actual.status, cambios.status)) {
      if (opciones?.fromOutbox && shouldDiscardStatus(actual.status, cambios.status)) {
        delete cambios.status;
      } else {
        throw ApiError.conflict(
          'PROJECT_INVALID_TRANSITION',
          `Una obra en ${actual.status} no puede pasar a ${cambios.status}`,
        );
      }
    }

    // Contra el estado actual y no contra "vino en el payload": `canTransition`
    // acepta quedarse donde está, así que guardar la ficha entera desde un
    // formulario llenaría el historial de transiciones de un estado a sí mismo.
    const transicion = cambios.status && cambios.status !== actual.status
      ? cambios.status
      : null;

    // Con el estado descartado el objeto puede quedar vacío, y ahí un `update`
    // de TypeORM solo toca `updated_at`. Se evita para no mover el cursor del
    // pull por una operación que no cambió nada.
    if (Object.keys(cambios).length > 0) {
      await this.projects.update({ id }, cambios);
    }

    if (transicion) {
      await this.registrarHito(
        actual,
        actual.status,
        transicion,
        currentTenant()?.membershipId ?? null,
        opciones?.occurredAt,
      );
    }
    return this.get(id);
  }

  /**
   * El hito que persiste el cambio. Lo escribe el servidor por los dos caminos
   * —REST y bandeja— para que el historial no dependa de que un cliente se
   * acuerde de registrarlo.
   *
   * `deviceRecordedAt` sale del `occurredAt` de la operación: por REST no hay
   * cola, así que ahí las dos marcas coinciden y eso es la verdad, no un relleno.
   */
  private async registrarHito(
    project: Project,
    from: ProjectStatus | null,
    to: ProjectStatus,
    membershipId: string | null,
    occurredAt?: string,
  ): Promise<void> {
    const ahora = new Date();
    await this.statusChanges.save(this.statusChanges.create({
      id: newId(),
      companyId: project.companyId,
      project: { id: project.id } as ProjectStatusChange['project'],
      fromStatus: from,
      toStatus: to,
      changedBy: membershipId
        ? ({ id: membershipId } as ProjectStatusChange['changedBy'])
        : null,
      deviceRecordedAt: occurredAt ? new Date(occurredAt) : ahora,
      serverReceivedAt: ahora,
      deletedAt: null,
    }));
  }

  async remove(id: string): Promise<void> {
    await this.get(id);
    await this.projects.update({ id }, { deletedAt: new Date() });
  }

  async assign(projectId: string, dto: AssignCrewDto, tenant: TenantContext): Promise<ProjectAssignment> {
    await this.get(projectId);
    if (!dto.crewId === !dto.membershipId) {
      throw new BadRequestException('Indicar cuadrilla o persona, no ambas');
    }
    const assignment = this.assignments.create({
      id: newId(),
      companyId: tenant.companyId,
      project: { id: projectId } as ProjectAssignment['project'],
      crew: dto.crewId ? ({ id: dto.crewId } as ProjectAssignment['crew']) : null,
      membership: dto.membershipId ? ({ id: dto.membershipId } as ProjectAssignment['membership']) : null,
      workDate: dto.workDate,
      plannedHeadcount: dto.plannedHeadcount ?? null,
      deletedAt: null,
    });
    return this.assignments.save(assignment);
  }

  listAssignments(projectId: string): Promise<ProjectAssignment[]> {
    return this.assignments.find({
      where: { project: { id: projectId }, deletedAt: IsNull() },
      relations: { crew: true, membership: true },
      order: { workDate: 'ASC' },
    });
  }
  // ------------------------------------------------------------ bitácora

  /**
   * Una nota de la obra.
   *
   * `INTERNAL` es el default y no llega a ningún lado. `CLIENT` se aprueba y
   * publica en el mismo acto —quien escribe es `OWNER` o `ADMIN`, no hay un
   * segundo actor que revise— y **eleva a `CLIENT` las fotos adjuntas que
   * estaban en `INTERNAL`**: el portal descarta en silencio las que no lo son,
   * así que sin eso la nota le llegaría al cliente sin ninguna foto.
   */
  @Transactional()
  async createUpdate(
    projectId: string,
    dto: CreateProjectUpdateDto,
    tenant: TenantContext,
  ): Promise<ProjectUpdate> {
    await this.get(projectId);

    const id = dto.id ?? newId();
    if (dto.id && (await this.updates.findOne({ where: { id } }))) {
      throw new ConflictException('Ya existe una nota con ese id');
    }

    const assetIds = dto.assetIds ?? [];
    const adjuntas = assetIds.length
      ? await this.assets.find({
          where: assetIds.map((assetId) => ({ id: assetId, deletedAt: IsNull() })),
          relations: { project: true },
        })
      : [];

    // Adjuntar es elegir entre las fotos de esta obra, no entre todas las de la
    // empresa. Un id que no está o que es de otra obra se rechaza entero.
    if (adjuntas.length !== assetIds.length
      || adjuntas.some((a) => a.project.id !== projectId)) {
      throw ApiError.badRequest(
        'ASSET_NOT_IN_PROJECT',
        'Solo se pueden adjuntar fotos de esta obra',
      );
    }

    const visibility = dto.visibility ?? 'INTERNAL';
    const paraElCliente = visibility === 'CLIENT';
    const ahora = new Date();

    await this.updates.save(this.updates.create({
      id,
      companyId: tenant.companyId,
      project: { id: projectId } as ProjectUpdate['project'],
      author: { id: tenant.membershipId } as ProjectUpdate['author'],
      body: dto.body,
      visibility,
      approvedBy: paraElCliente
        ? ({ id: tenant.membershipId } as ProjectUpdate['approvedBy'])
        : null,
      publishedAt: paraElCliente ? ahora : null,
      deletedAt: null,
    }));

    if (assetIds.length) {
      await this.updateAssets.save(assetIds.map((assetId, position) =>
        this.updateAssets.create({ updateId: id, assetId, position })));
    }

    // Un escalón, nunca hasta PUBLIC y nunca hacia abajo. Pasa por el servicio
    // de media y no por un update directo: la regla de la escalera vive ahí.
    if (paraElCliente) {
      for (const asset of adjuntas.filter((a) => a.visibility === 'INTERNAL')) {
        await this.media.setVisibility(asset.id, { visibility: 'CLIENT' });
      }
    }

    return (await this.updates.findOne({ where: { id } }))!;
  }
}
