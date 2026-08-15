import { MediaService } from './media.service';
import { MediaAsset, MediaVisibility } from './entities/media-asset.entity';

/**
 * La escalera INTERNAL -> CLIENT -> PUBLIC sube de a un escalón.
 *
 * Estuvo declarada en la ficha de dominio y sin aplicar en ningún lado hasta
 * SPEC-0010: el servicio aceptaba cualquier salto y la base tampoco lo miraba.
 */
function servicio(asset: Partial<MediaAsset>) {
  const assets = {
    findOne: jest.fn().mockResolvedValue(asset as MediaAsset),
    update: jest.fn().mockResolvedValue({ affected: 1 }),
  };
  const service = new MediaService(assets as never, {} as never, {} as never, {} as never);
  return { service, assets };
}

const base: Partial<MediaAsset> = {
  id: '019feef4-94d8-76fd-b6ee-0e67fc698213',
  kind: 'PHOTO',
  uploadStatus: 'READY',
  exifStrippedAt: new Date(),
  deletedAt: null,
};

async function subir(desde: MediaVisibility, hasta: MediaVisibility) {
  const { service, assets } = servicio({ ...base, visibility: desde });
  await service.setVisibility(base.id!, { visibility: hasta });
  return assets.update;
}

describe('la escalera de visibilidad', () => {
  it('sube de a un escalón', async () => {
    expect(await subir('INTERNAL', 'CLIENT')).toHaveBeenCalled();
    expect(await subir('CLIENT', 'PUBLIC')).toHaveBeenCalled();
  });

  it('INTERNAL no salta a PUBLIC de una vez', async () => {
    const { service } = servicio({ ...base, visibility: 'INTERNAL' });

    await expect(service.setVisibility(base.id!, { visibility: 'PUBLIC' }))
      .rejects.toMatchObject({ code: 'VISIBILITY_SKIPS_STEP' });
  });

  it('bajar no se restringe: sacar algo de la vista es siempre urgente', async () => {
    expect(await subir('PUBLIC', 'INTERNAL')).toHaveBeenCalled();
    expect(await subir('PUBLIC', 'CLIENT')).toHaveBeenCalled();
    expect(await subir('CLIENT', 'INTERNAL')).toHaveBeenCalled();
  });

  it('quedarse en el mismo nivel no es un salto', async () => {
    expect(await subir('CLIENT', 'CLIENT')).toHaveBeenCalled();
  });

  it('el asset que no terminó de subir no llega a PUBLIC', async () => {
    const { service } = servicio({ ...base, visibility: 'CLIENT', uploadStatus: 'PENDING' });

    await expect(service.setVisibility(base.id!, { visibility: 'PUBLIC' }))
      .rejects.toMatchObject({ code: 'UPLOAD_NOT_READY' });
  });
});
