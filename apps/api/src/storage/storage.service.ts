import { ApiError } from '../common/errors/api-error';
import { Injectable, Logger } from '@nestjs/common';
import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export const UPLOAD_TTL_SECONDS = 15 * 60;
export const DOWNLOAD_TTL_SECONDS = 10 * 60;

/**
 * Backblaze B2 vía su API compatible con S3 (ADR-0010). Nada acá es específico
 * de B2: cambiar de proveedor son tres variables de entorno.
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor() {
    this.bucket = process.env.STORAGE_BUCKET ?? 'snapline-dev';
    this.client = new S3Client({
      region: process.env.STORAGE_REGION ?? 'us-west-004',
      endpoint: process.env.STORAGE_ENDPOINT ?? 'https://s3.us-west-004.backblazeb2.com',
      forcePathStyle: process.env.STORAGE_FORCE_PATH_STYLE === 'true',
      credentials: {
        accessKeyId: process.env.STORAGE_ACCESS_KEY_ID ?? '',
        secretAccessKey: process.env.STORAGE_SECRET_ACCESS_KEY ?? '',
      },
    });

    if (!this.configured) {
      this.logger.warn(
        'Backblaze sin credenciales. Registrar fotos falla hasta configurar STORAGE_ACCESS_KEY_ID y STORAGE_SECRET_ACCESS_KEY.',
      );
    }
  }

  get configured(): boolean {
    return Boolean(process.env.STORAGE_ACCESS_KEY_ID && process.env.STORAGE_SECRET_ACCESS_KEY);
  }

  /**
   * Sin credenciales la firma sale bien formada pero el bucket responde 403 al
   * subir, lo cual es un error confuso y tardío. Mejor fallar acá y decir por qué.
   */
  private assertConfigured(): void {
    if (!this.configured) {
      throw ApiError.unavailable(
        'STORAGE_NOT_CONFIGURED',
        'Almacenamiento sin configurar: faltan STORAGE_ACCESS_KEY_ID y STORAGE_SECRET_ACCESS_KEY',
      );
    }
  }

  /**
   * URL para que el dispositivo suba directo al bucket, sin pasar el archivo por
   * el API. El content-type va firmado: subir un tipo distinto al declarado falla.
   */
  presignUpload(key: string, contentType: string): Promise<string> {
    this.assertConfigured();
    return getSignedUrl(
      this.client,
      new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType }),
      { expiresIn: UPLOAD_TTL_SECONDS, signableHeaders: new Set(['content-type']) },
    );
  }

  /**
   * El bucket no es público (ADR-0010): todo se sirve firmado y con vida corta.
   * Un bucket abierto deja las fotos de la casa de un cliente al alcance de
   * quien adivine la ruta.
   */
  presignDownload(key: string, ttlSeconds = DOWNLOAD_TTL_SECONDS): Promise<string> {
    this.assertConfigured();
    return getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn: ttlSeconds },
    );
  }

  async getObject(key: string): Promise<Buffer> {
    this.assertConfigured();
    const res = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    return Buffer.from(await res.Body!.transformToByteArray());
  }

  async putObject(key: string, body: Buffer, contentType: string): Promise<void> {
    this.assertConfigured();
    await this.client.send(new PutObjectCommand({
      Bucket: this.bucket, Key: key, Body: body, ContentType: contentType,
    }));
  }

  async remove(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}
