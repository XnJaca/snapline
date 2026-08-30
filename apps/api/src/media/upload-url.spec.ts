import { ApiError } from '../common/errors/api-error';
import { MediaService } from './media.service';
import { MediaAsset } from './entities/media-asset.entity';

// Que `register` devuelva la URL con su vencimiento no se prueba acá: está
// envuelto en @Transactional, que exige un DataSource real. Lo garantiza el
// tipo de retorno (RegisterAssetResponseDto) y lo verifica el e2e.

/**
 * La URL de subida de un asset ya registrado: el camino del reintento offline.
 * `media.register` entra por la bandeja sin poder devolver dónde subir, y el
 * binario sube después con esto.
 */
function servicio(asset: Partial<MediaAsset>): MediaService {
  const assets = {
    findOne: jest.fn().mockResolvedValue(asset as MediaAsset),
  };
  const storage = {
    presignUpload: jest.fn().mockResolvedValue('https://firmada.example/put'),
  };
  return new MediaService(assets as never, {} as never, {} as never, storage as never);
}

const base: Partial<MediaAsset> = {
  id: '019feef4-94d8-76fd-b6ee-0e67fc698213',
  storageKey: 'c1/p1/a1.jpg',
  mime: 'image/jpeg',
  deletedAt: null,
};

describe('la URL de subida de un asset registrado', () => {
  it('un asset pendiente recibe su URL firmada con vencimiento', async () => {
    const resultado = await servicio({ ...base, uploadStatus: 'PENDING' }).uploadUrl(base.id!);

    expect(resultado.url).toContain('https://');
    expect(resultado.expiresInSeconds).toBeGreaterThan(0);
  });

  it('uno que falló también: es exactamente el caso del reintento', async () => {
    const resultado = await servicio({ ...base, uploadStatus: 'FAILED' }).uploadUrl(base.id!);

    expect(resultado.url).toContain('https://');
  });

  it('uno ya subido no: markUploaded le quitó el EXIF y una segunda subida lo repondría', async () => {
    await expect(
      servicio({ ...base, uploadStatus: 'READY' }).uploadUrl(base.id!),
    ).rejects.toMatchObject({ code: 'MEDIA_ALREADY_UPLOADED' });
  });
});

// El guard de arriba usa ApiError: que siga siendo el envelope de ADR-0011.
it('el rechazo es un ApiError con código estable, no un throw suelto', async () => {
  try {
    await servicio({ ...base, uploadStatus: 'READY' }).uploadUrl(base.id!);
    fail('debió rechazar');
  } catch (e) {
    expect(e).toBeInstanceOf(ApiError);
  }
});
