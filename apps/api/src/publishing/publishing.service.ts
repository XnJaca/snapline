import { ApiError } from '../common/errors/api-error';
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Repository } from 'typeorm';
import { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { StorageService } from '../storage/storage.service';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { Project } from '../projects/entities/project.entity';
import { BeforeAfterPair } from '../media/entities/before-after-pair.entity';
import { PublishedProject } from './entities/published-project.entity';
import { PublishedProjectAsset } from './entities/published-project-asset.entity';
import { SocialPost } from './entities/social-post.entity';
import { SocialPostAsset } from './entities/social-post-asset.entity';
import { Testimonial } from './entities/testimonial.entity';
import { BeforeAfterDto, CreateTestimonialDto, MarkContentUsedDto, PublishProjectDto } from './dto/publishing.dto';

// Las imágenes del portafolio se firman largo: el sitio es estático y regenera
// los links en cada build. Ver el pendiente de CDN en ADR-0010.
const PUBLIC_URL_TTL_SECONDS = 24 * 60 * 60;

@Injectable()
export class PublishingService {
  constructor(
    @InjectRepository(PublishedProject) private readonly published: Repository<PublishedProject>,
    @InjectRepository(PublishedProjectAsset) private readonly publishedAssets: Repository<PublishedProjectAsset>,
    @InjectRepository(BeforeAfterPair) private readonly pairs: Repository<BeforeAfterPair>,
    @InjectRepository(SocialPost) private readonly posts: Repository<SocialPost>,
    @InjectRepository(SocialPostAsset) private readonly postAssets: Repository<SocialPostAsset>,
    @InjectRepository(Testimonial) private readonly testimonials: Repository<Testimonial>,
    @InjectRepository(MediaAsset) private readonly assets: Repository<MediaAsset>,
    @InjectRepository(Project) private readonly projects: Repository<Project>,
    private readonly storage: StorageService,
  ) {}

  /**
   * Publicar exige que todos los assets estén en PUBLIC y con EXIF limpio.
   * El photo release lo verifica además un trigger de la base: si el cliente no
   * lo otorgó, el INSERT falla aunque esto pase.
   */
  @Transactional()
  async publish(projectId: string, dto: PublishProjectDto, tenant: TenantContext): Promise<PublishedProject> {
    const project = await this.projects.findOne({ where: { id: projectId, deletedAt: IsNull() } });
    if (!project) throw new NotFoundException('Proyecto no encontrado');

    const previous = await this.published.findOne({ where: { project: { id: projectId } } });
    if (previous && !previous.unpublishedAt) {
      throw ApiError.conflict('ALREADY_PUBLISHED', 'El proyecto ya está publicado');
    }

    const ids = [...new Set([dto.heroAssetId, ...dto.assetIds])];
    const assets = await this.assets.find({ where: { id: In(ids), deletedAt: IsNull() } });
    if (assets.length !== ids.length) throw new BadRequestException('Alguna foto no existe');

    const notPublic = assets.filter((a) => a.visibility !== 'PUBLIC');
    if (notPublic.length) {
      throw ApiError.badRequest('ASSET_NOT_PUBLIC',
        `${notPublic.length} foto(s) no están en PUBLIC. Subirlas de nivel primero.`);
    }
    const withExif = assets.filter((a) => a.kind === 'PHOTO' && !a.exifStrippedAt);
    if (withExif.length) {
      throw ApiError.badRequest('EXIF_NOT_STRIPPED',
        `${withExif.length} foto(s) conservan el EXIF: publicarlas expondría la dirección del cliente.`);
    }

    // Republicar reusa la fila y conserva el slug: el link ya está indexado y
    // devolver 404 en una URL que existía es peor que no haberla publicado.
    const id = previous?.id ?? newId();
    const content = {
      title: dto.title,
      summary: dto.summary ?? null,
      heroAsset: { id: dto.heroAssetId } as PublishedProject['heroAsset'],
      serviceType: project.serviceType,
      city: dto.city ?? null,
      testimonial: dto.testimonialId ? ({ id: dto.testimonialId } as PublishedProject['testimonial']) : null,
      publishedAt: new Date(),
      unpublishedAt: null,
    };

    if (previous) {
      await this.published.update({ id }, content as QueryDeepPartialEntity<PublishedProject>);
      await this.publishedAssets.delete({ publishedProjectId: id });
    } else {
      await this.published.save(this.published.create({
        id,
        companyId: tenant.companyId,
        project: { id: projectId } as PublishedProject['project'],
        slug: dto.slug ?? slugify(dto.title),
        ...content,
      }));
    }

    await this.publishedAssets.save(dto.assetIds.map((assetId, position) =>
      this.publishedAssets.create({ publishedProjectId: id, assetId, position })));

    await this.projects.update({ id: projectId }, { publishedAt: new Date() });
    return this.get(id);
  }

  // Se despublica, no se borra: el link ya está indexado.
  async unpublish(id: string): Promise<PublishedProject> {
    const found = await this.get(id);
    if (found.unpublishedAt) throw new ConflictException('Ya está despublicado');
    await this.published.update({ id }, { unpublishedAt: new Date() });
    await this.projects.update({ id: found.projectId }, { publishedAt: null });
    return this.get(id);
  }

  async get(id: string): Promise<PublishedProject> {
    const found = await this.published.findOne({
      where: { id }, relations: { heroAsset: true, testimonial: true },
    });
    if (!found) throw new NotFoundException('Publicación no encontrada');
    return found;
  }

  list(): Promise<PublishedProject[]> {
    return this.published.find({ relations: { heroAsset: true }, order: { publishedAt: 'DESC' } });
  }

  // ------------------------------------------------------- antes / después

  @Transactional()
  async addPair(projectId: string, dto: BeforeAfterDto, tenant: TenantContext): Promise<BeforeAfterPair> {
    if (dto.beforeAssetId === dto.afterAssetId) {
      throw new BadRequestException('El antes y el después no pueden ser la misma foto');
    }
    const assets = await this.assets.find({
      where: { id: In([dto.beforeAssetId, dto.afterAssetId]), project: { id: projectId }, deletedAt: IsNull() },
    });
    if (assets.length !== 2) throw new BadRequestException('Ambas fotos deben ser de ese proyecto');

    return this.pairs.save(this.pairs.create({
      id: newId(),
      companyId: tenant.companyId,
      project: { id: projectId } as BeforeAfterPair['project'],
      beforeAsset: { id: dto.beforeAssetId } as BeforeAfterPair['beforeAsset'],
      afterAsset: { id: dto.afterAssetId } as BeforeAfterPair['afterAsset'],
      caption: dto.caption ?? null,
      deletedAt: null,
    }));
  }

  listPairs(projectId: string): Promise<BeforeAfterPair[]> {
    return this.pairs.find({
      where: { project: { id: projectId }, deletedAt: IsNull() },
      relations: { beforeAsset: true, afterAsset: true },
    });
  }

  // ---------------------------------------------------------- testimonios

  async createTestimonial(dto: CreateTestimonialDto, tenant: TenantContext): Promise<Testimonial> {
    return this.testimonials.save(this.testimonials.create({
      id: newId(),
      companyId: tenant.companyId,
      customer: { id: dto.customerId } as Testimonial['customer'],
      project: { id: dto.projectId } as Testimonial['project'],
      rating: dto.rating ?? null,
      body: dto.body,
      approvedAt: null,
      publishedAt: null,
      deletedAt: null,
    }));
  }

  async approveTestimonial(id: string): Promise<Testimonial> {
    const found = await this.testimonials.findOne({ where: { id, deletedAt: IsNull() } });
    if (!found) throw new NotFoundException('Testimonio no encontrado');
    await this.testimonials.update({ id }, { approvedAt: new Date(), publishedAt: new Date() });
    return (await this.testimonials.findOne({ where: { id } }))!;
  }

  // ------------------------------------------------------- feed de redes

  /**
   * Material listo para producir redes, con lo ya usado marcado. Es lo que hoy
   * se pide por WhatsApp y llega sin identificar.
   */
  async socialFeed(): Promise<unknown[]> {
    const pubs = await this.published.find({
      where: { unpublishedAt: IsNull() }, relations: { heroAsset: true }, order: { publishedAt: 'DESC' },
    });
    const used = await this.postAssets.find();
    const usedIds = new Set(used.map((u) => u.assetId));

    return Promise.all(pubs.map(async (p) => {
      const pairs = await this.listPairs(p.projectId);
      return {
        publishedProjectId: p.id,
        projectId: p.projectId,
        title: p.title,
        serviceType: p.serviceType,
        city: p.city,
        publishedAt: p.publishedAt,
        heroUrl: await this.storage.presignDownload(p.heroAsset.storageKey, PUBLIC_URL_TTL_SECONDS),
        beforeAfterPairs: await Promise.all(pairs.map(async (pair) => ({
          caption: pair.caption,
          alreadyUsed: usedIds.has(pair.beforeAssetId) || usedIds.has(pair.afterAssetId),
          beforeUrl: await this.storage.presignDownload(pair.beforeAsset.storageKey, PUBLIC_URL_TTL_SECONDS),
          afterUrl: await this.storage.presignDownload(pair.afterAsset.storageKey, PUBLIC_URL_TTL_SECONDS),
        }))),
      };
    }));
  }

  @Transactional()
  async markContentUsed(dto: MarkContentUsedDto, tenant: TenantContext): Promise<SocialPost> {
    const post = await this.posts.save(this.posts.create({
      id: newId(),
      companyId: tenant.companyId,
      sourceProject: dto.sourceProjectId ? ({ id: dto.sourceProjectId } as SocialPost['sourceProject']) : null,
      platform: dto.platform as SocialPost['platform'],
      content: dto.content ?? null,
      status: 'POSTED',
      scheduledFor: null,
      postedAt: new Date(),
      deletedAt: null,
    }));
    await this.postAssets.save(dto.assetIds.map((assetId, position) =>
      this.postAssets.create({ socialPostId: post.id, assetId, position })));
    return post;
  }

  // ------------------------------------------------- portafolio público

  /**
   * Sin autenticación: es lo que consume el sitio en Astro. Va por
   * public_portfolio(), una función SECURITY DEFINER — sin ella RLS devuelve
   * cero filas porque el request anónimo no tiene contexto de tenant.
   */
  async publicPortfolio(companySlug: string): Promise<unknown[]> {
    const rows = await this.published.query(
      'SELECT * FROM public_portfolio($1)', [companySlug],
    ) as Record<string, string | null>[];

    return Promise.all(rows.map(async ({ hero_key, service_type, published_at, testimonial_body, testimonial_rating, ...row }) => ({
      ...row,
      serviceType: service_type,
      publishedAt: published_at,
      testimonial: testimonial_body ? { body: testimonial_body, rating: testimonial_rating } : null,
      heroUrl: await this.storage.presignDownload(hero_key!, PUBLIC_URL_TTL_SECONDS),
    })));
  }
}

function slugify(text: string): string {
  return text
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}
