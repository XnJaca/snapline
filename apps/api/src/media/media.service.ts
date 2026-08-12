import { ApiError } from '../common/errors/api-error';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Project } from '../projects/entities/project.entity';
import { MediaAsset } from './entities/media-asset.entity';
import { RegisterAssetDto, RegisterAssetResponseDto, SetVisibilityDto, SignedUrlDto } from './dto/media.dto';
import sharp from 'sharp';
import { DOWNLOAD_TTL_SECONDS, StorageService, UPLOAD_TTL_SECONDS } from '../storage/storage.service';

const MIME_EXTENSIONS: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/heic': '.heic',
  'image/webp': '.webp',
  'video/mp4': '.mp4',
  'application/pdf': '.pdf',
};

function extensionFor(mime: string): string {
  return MIME_EXTENSIONS[mime] ?? '';
}

@Injectable()
export class MediaService {
  constructor(
    @InjectRepository(MediaAsset) private readonly assets: Repository<MediaAsset>,
    @InjectRepository(Project) private readonly projects: Repository<Project>,
    private readonly storage: StorageService,
  ) {}

  list(projectId: string): Promise<MediaAsset[]> {
    return this.assets.find({
      where: { project: { id: projectId }, deletedAt: IsNull() },
      order: { capturedAt: 'ASC', createdAt: 'ASC' },
    });
  }

  async get(id: string): Promise<MediaAsset> {
    const found = await this.assets.findOne({ where: { id, deletedAt: IsNull() } });
    if (!found) throw new NotFoundException('Asset no encontrado');
    return found;
  }

  /**
   * Registra el asset y devuelve dónde subirlo. El dispositivo sube aparte y
   * confirma con markUploaded, así el registro existe desde el disparo de la foto.
   */
  @Transactional()
  async register(dto: RegisterAssetDto, tenant: TenantContext): Promise<RegisterAssetResponseDto> {
    const project = await this.projects.findOne({ where: { id: dto.projectId, deletedAt: IsNull() } });
    if (!project) throw new NotFoundException('Proyecto no encontrado');

    // Un reintento con el mismo checksum devuelve el asset existente, no duplica.
    const existing = await this.assets.findOne({
      where: { project: { id: dto.projectId }, checksum: dto.checksum, deletedAt: IsNull() },
    });
    if (existing) {
      return {
        asset: existing,
        uploadUrl: await this.storage.presignUpload(existing.storageKey, existing.mime),
        uploadUrlExpiresInSeconds: UPLOAD_TTL_SECONDS,
      };
    }

    const id = dto.id ?? newId();
    const asset = this.assets.create({
      id,
      companyId: tenant.companyId,
      project: { id: dto.projectId } as MediaAsset['project'],
      kind: dto.kind,
      documentKind: null,
      storageKey: `${tenant.companyId}/${dto.projectId}/${id}${extensionFor(dto.mime)}`,
      mime: dto.mime,
      bytes: dto.bytes ?? null,
      width: dto.width ?? null,
      height: dto.height ?? null,
      capturedAt: dto.capturedAt ? new Date(dto.capturedAt) : null,
      uploadedBy: { id: tenant.membershipId } as MediaAsset['uploadedBy'],
      deviceLat: dto.deviceLat ?? null,
      deviceLng: dto.deviceLng ?? null,
      checksum: dto.checksum,
      uploadStatus: 'PENDING',
      visibility: 'INTERNAL',
      exifStrippedAt: null,
      deletedAt: null,
    });
    await this.assets.save(asset);
    return {
      asset: await this.get(id),
      uploadUrl: await this.storage.presignUpload(asset.storageKey, asset.mime),
      uploadUrlExpiresInSeconds: UPLOAD_TTL_SECONDS,
    };
  }

  async markUploaded(id: string): Promise<MediaAsset> {
    await this.get(id);
    await this.assets.update({ id }, { uploadStatus: 'READY' });
    return this.get(id);
  }

  /**
   * La escalera es INTERNAL -> CLIENT -> PUBLIC. Pasar a PUBLIC exige EXIF
   * limpio, y un trigger de la base lo rechaza aunque esto falle.
   */
  async setVisibility(id: string, dto: SetVisibilityDto): Promise<MediaAsset> {
    const asset = await this.get(id);
    if (dto.visibility === 'PUBLIC') {
      if (asset.uploadStatus !== 'READY') {
        throw ApiError.badRequest('UPLOAD_NOT_READY', 'El asset todavía no terminó de subir');
      }
      // Limpia sola en vez de exigir una llamada previa: olvidarla publicaba las
      // coordenadas de la casa del cliente, y eso no puede depender de recordar.
      if (asset.kind === 'PHOTO' && !asset.exifStrippedAt) {
        await this.stripExif(id);
      }
    }
    await this.assets.update({ id }, { visibility: dto.visibility });
    return this.get(id);
  }

  /**
   * Borra los metadatos del archivo en el bucket, de verdad. Antes esto solo
   * marcaba una fecha y la bandera mentía.
   *
   * Se reescribe el objeto en su lugar: los datos que importan del EXIF
   * (captured_at, coordenadas) ya viven en columnas, y las fotos que sirven de
   * evidencia de asistencia nunca llegan a PUBLIC, así que no se pierde nada.
   */
  @Transactional()
  async stripExif(id: string): Promise<MediaAsset> {
    const asset = await this.get(id);
    if (asset.exifStrippedAt) return asset;
    if (asset.uploadStatus !== 'READY') {
      throw ApiError.badRequest('UPLOAD_NOT_READY', 'El asset todavía no terminó de subir');
    }
    if (asset.kind !== 'PHOTO') {
      await this.assets.update({ id }, { exifStrippedAt: new Date() });
      return this.get(id);
    }

    const original = await this.storage.getObject(asset.storageKey);
    let clean: Buffer;
    let width: number | undefined;
    let height: number | undefined;
    try {
      // rotate() aplica la orientación del EXIF antes de borrarlo: sin esto, una
      // foto vertical queda de costado apenas se le quitan los metadatos.
      const result = await sharp(original).rotate().toBuffer({ resolveWithObject: true });
      clean = result.data;
      width = result.info.width;
      height = result.info.height;
    } catch (e) {
      throw new BadRequestException(
        `No se pudo procesar la imagen (${asset.mime}): ${(e as Error).message}`,
      );
    }

    await this.storage.putObject(asset.storageKey, clean, asset.mime);
    await this.assets.update({ id }, {
      exifStrippedAt: new Date(),
      bytes: clean.byteLength,
      width,
      height,
    });
    return this.get(id);
  }

  /** URL firmada y de vida corta para ver el archivo. Nunca una ruta pública. */
  async downloadUrl(id: string): Promise<SignedUrlDto> {
    const asset = await this.get(id);
    return {
      url: await this.storage.presignDownload(asset.storageKey),
      expiresInSeconds: DOWNLOAD_TTL_SECONDS,
    };
  }

  /**
   * La URL de subida de un asset que ya está registrado. Es el camino del
   * reintento offline: `media.register` entra por la bandeja sin poder devolver
   * dónde subir, y el binario sube después con esto.
   */
  async uploadUrl(id: string): Promise<SignedUrlDto> {
    const asset = await this.get(id);
    // Un asset ya subido no se vuelve a subir: markUploaded le quitó el EXIF, y
    // una segunda subida lo repondría con las coordenadas de la casa adentro.
    if (asset.uploadStatus === 'READY') {
      throw ApiError.conflict('MEDIA_ALREADY_UPLOADED', 'El archivo ya está subido');
    }
    return {
      url: await this.storage.presignUpload(asset.storageKey, asset.mime),
      expiresInSeconds: UPLOAD_TTL_SECONDS,
    };
  }
}
