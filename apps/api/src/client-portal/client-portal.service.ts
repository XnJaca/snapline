import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { createHash, randomBytes } from 'node:crypto';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { ApiError } from '../common/errors/api-error';
import { TenantContext } from '../tenant/tenant-context';
import { DataSource } from 'typeorm';
import { InjectDataSource } from '@nestjs/typeorm';
import { StorageService } from '../storage/storage.service';
import { TenantService } from '../tenant/tenant.service';
import { Project } from '../projects/entities/project.entity';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { ServiceOffer } from '../leads/entities/service-offer.entity';
import { Lead } from '../leads/entities/lead.entity';
import { ClientAccess } from './entities/client-access.entity';
import { ProjectUpdate } from './entities/project-update.entity';
import { ProjectUpdateAsset } from './entities/project-update-asset.entity';
import {
  ClientProjectViewDto, GrantAccessDto, GrantAccessResultDto, PublishUpdateDto, RequestOfferDto,
} from './dto/client-portal.dto';

const DEFAULT_EXPIRY_DAYS = 90;
const PHOTO_URL_TTL_SECONDS = 60 * 60;

/** El token viaja por SMS: en la base solo vive su hash. */
const hashToken = (raw: string) => createHash('sha256').update(raw).digest('hex');

interface ResolvedAccess {
  id: string;
  companyId: string;
  customerId: string;
  projectId: string | null;
}

@Injectable()
export class ClientPortalService {
  constructor(
    @InjectRepository(ClientAccess) private readonly access: Repository<ClientAccess>,
    @InjectRepository(ProjectUpdate) private readonly updates: Repository<ProjectUpdate>,
    @InjectRepository(ProjectUpdateAsset) private readonly updateAssets: Repository<ProjectUpdateAsset>,
    @InjectRepository(Project) private readonly projects: Repository<Project>,
    @InjectRepository(MediaAsset) private readonly assets: Repository<MediaAsset>,
    @InjectRepository(ServiceOffer) private readonly offers: Repository<ServiceOffer>,
    @InjectRepository(Lead) private readonly leads: Repository<Lead>,
    private readonly storage: StorageService,
    private readonly tenants: TenantService,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  /**
   * Canjea el token por su acceso. Va por client_access_by_token(), una función
   * SECURITY DEFINER: el visitante no tiene contexto de tenant, así que sin ella
   * RLS devuelve cero filas.
   */
  private async resolveToken(rawToken: string): Promise<ResolvedAccess> {
    const [row] = await this.dataSource.query<ResolvedAccess[]>(
      `SELECT id, company_id AS "companyId", customer_id AS "customerId",
              project_id AS "projectId"
       FROM client_access_by_token($1)`,
      [hashToken(rawToken)],
    );
    if (!row) throw ApiError.unauthorized('TOKEN_INVALID', 'El link no es válido o venció');
    return row;
  }

  // ------------------------------------------------------- lado empresa

  @Transactional()
  async grant(dto: GrantAccessDto, tenant: TenantContext, baseUrl: string): Promise<GrantAccessResultDto> {
    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + (dto.expiresInDays ?? DEFAULT_EXPIRY_DAYS) * 86_400_000);
    const id = newId();

    await this.access.save(this.access.create({
      id,
      companyId: tenant.companyId,
      customer: { id: dto.customerId } as ClientAccess['customer'],
      project: dto.projectId ? ({ id: dto.projectId } as ClientAccess['project']) : null,
      tokenHash: hashToken(token),
      expiresAt,
      lastSeenAt: null,
      claimedUser: null,
      revokedAt: null,
    }));

    return { id, token, url: `${baseUrl}/p/${token}`, expiresAt: expiresAt.toISOString() };
  }

  async revoke(id: string): Promise<void> {
    const found = await this.access.findOne({ where: { id } });
    if (!found) throw ApiError.notFound('NOT_FOUND', 'Acceso no encontrado');
    await this.access.update({ id }, { revokedAt: new Date() });
  }

  /** Nada llega al cliente sin esto: publicar es un acto explícito. */
  @Transactional()
  async publishUpdate(projectId: string, dto: PublishUpdateDto, tenant: TenantContext): Promise<ProjectUpdate> {
    const project = await this.projects.findOne({ where: { id: projectId, deletedAt: IsNull() } });
    if (!project) throw ApiError.notFound('NOT_FOUND', 'Proyecto no encontrado');

    const id = newId();
    await this.updates.save(this.updates.create({
      id,
      companyId: tenant.companyId,
      project: { id: projectId } as ProjectUpdate['project'],
      author: { id: tenant.membershipId } as ProjectUpdate['author'],
      body: dto.body,
      visibility: 'CLIENT',
      approvedBy: { id: tenant.membershipId } as ProjectUpdate['approvedBy'],
      publishedAt: new Date(),
      deletedAt: null,
    }));

    if (dto.assetIds?.length) {
      await this.updateAssets.save(dto.assetIds.map((assetId, position) =>
        this.updateAssets.create({ updateId: id, assetId, position })));
    }
    return (await this.updates.findOne({ where: { id } }))!;
  }

  // -------------------------------------------------------- lado cliente

  /**
   * Anónimo: el token es la única credencial. Se resuelve fuera del scope de
   * tenant —el visitante no tiene empresa— y a partir de ahí todo corre dentro
   * del tenant que el token identifica.
   */
  async view(rawToken: string): Promise<ClientProjectViewDto[]> {
    const access = await this.resolveToken(rawToken);

    // El visitante del portal no es miembro: no tiene rol ni membresía. Solo se
    // usa para abrir el scope de tenant de esa empresa.
    const tenant: TenantContext = {
      companyId: access.companyId, membershipId: '', userId: '', role: 'WORKER',
    };

    return this.tenants.runAs(tenant, async () => {
      await this.access.update({ id: access.id }, { lastSeenAt: new Date() });

      const projects = await this.projects.find({
        where: {
          deletedAt: IsNull(),
          ...(access.projectId
            ? { id: access.projectId }
            : { customer: { id: access.customerId } }),
        },
        order: { createdAt: 'DESC' },
      });

      const offers = await this.offers.find({ where: { active: true, deletedAt: IsNull() } });

      return Promise.all(projects.map(async (p) => this.toClientView(p, offers)));
    });
  }

  @Transactional()
  async requestOffer(rawToken: string, dto: RequestOfferDto): Promise<{ leadId: string }> {
    const access = await this.resolveToken(rawToken);

    const tenant: TenantContext = { companyId: access.companyId, membershipId: '', userId: '', role: 'WORKER' };
    return this.tenants.runAs(tenant, async () => {
      const id = newId();
      await this.leads.save(this.leads.create({
        id,
        companyId: access.companyId,
        customer: { id: access.customerId } as Lead['customer'],
        offer: { id: dto.offerId } as Lead['offer'],
        sourceProject: access.projectId ? ({ id: access.projectId } as Lead['sourceProject']) : null,
        status: 'NEW',
        convertedProject: null,
        notes: dto.notes ?? null,
        deletedAt: null,
      }));
      return { leadId: id };
    });
  }

  /**
   * En modo STAGES el cliente ve la etapa y nada más. Es el default a propósito:
   * una foto de media obra genera más preguntas que confianza (ADR-0004).
   */
  private async toClientView(project: Project, offers: ServiceOffer[]): Promise<ClientProjectViewDto> {
    const base = {
      id: project.id,
      name: project.name,
      stage: project.clientStage,
      visibilityMode: project.clientVisibilityMode,
      offers: offers.map((o) => ({ id: o.id, title: o.title, pitch: o.pitch })),
    };

    if (project.clientVisibilityMode === 'STAGES') {
      return { ...base, updates: [], photos: [] };
    }

    const updates = await this.updates.find({
      where: { project: { id: project.id }, deletedAt: IsNull() },
      order: { publishedAt: 'DESC' },
    });
    const visibles = updates.filter((u) => u.publishedAt);

    const links = visibles.length
      ? await this.updateAssets.find({ where: visibles.map((u) => ({ updateId: u.id })) })
      : [];
    const assets = await this.assets.find({
      where: { project: { id: project.id }, visibility: 'CLIENT', deletedAt: IsNull() },
      order: { capturedAt: 'ASC' },
    });
    const byId = new Map(assets.map((a) => [a.id, a]));

    const toPhoto = async (a: MediaAsset) => ({
      id: a.id,
      url: await this.storage.presignDownload(a.storageKey, PHOTO_URL_TTL_SECONDS),
      capturedAt: a.capturedAt?.toISOString() ?? null,
    });

    return {
      ...base,
      updates: await Promise.all(visibles.map(async (u) => ({
        id: u.id,
        body: u.body,
        publishedAt: u.publishedAt!.toISOString(),
        photos: await Promise.all(
          links.filter((l) => l.updateId === u.id)
            .map((l) => byId.get(l.assetId))
            .filter((a): a is MediaAsset => !!a)
            .map(toPhoto),
        ),
      }))),
      photos: await Promise.all(assets.map(toPhoto)),
    };
  }
}
