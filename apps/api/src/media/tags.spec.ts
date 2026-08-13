import { MediaService } from './media.service';
import { MediaAsset } from './entities/media-asset.entity';
import { MediaTag } from './entities/media-tag.entity';

/**
 * Las etiquetas viajan dentro del asset, no como colección propia del pull:
 * `media_tag` no tiene `updated_at` ni `deleted_at` y el incremental depende de
 * los dos.
 *
 * Acá va solo la lectura. `setTags` está envuelto en @Transactional, que exige
 * un DataSource real, así que su comportamiento —incluido tocar el asset, del
 * que depende el pull— lo fija el e2e.
 */
function servicio(asset: Partial<MediaAsset>, filas: Partial<MediaTag>[] = []) {
  const assets = {
    findOne: jest.fn().mockResolvedValue(asset as MediaAsset),
  };
  const tags = {
    find: jest.fn().mockResolvedValue(filas as MediaTag[]),
  };
  const service = new MediaService(assets as never, tags as never, {} as never, {} as never);
  return { service, tags };
}

const id = '019feef4-94d8-76fd-b6ee-0e67fc698213';
const otro = '019feef4-94d8-76fd-b6ee-0e67fc698214';
const base: Partial<MediaAsset> = { id, kind: 'PHOTO', visibility: 'INTERNAL', deletedAt: null };

describe('las etiquetas de una foto', () => {
  it('el asset sale con las suyas', async () => {
    const { service } = servicio(base, [
      { assetId: id, tag: 'BEFORE' },
      { assetId: id, tag: 'DETAIL' },
    ]);

    expect((await service.getWithTags(id)).tags).toEqual(['BEFORE', 'DETAIL']);
  });

  it('sin ninguna sale con lista vacía, no con null', async () => {
    const { service } = servicio(base);

    expect((await service.getWithTags(id)).tags).toEqual([]);
  });

  it('en un lote, cada asset recibe las suyas y no las del vecino', async () => {
    const { service } = servicio(base, [
      { assetId: id, tag: 'BEFORE' },
      { assetId: otro, tag: 'AFTER' },
    ]);

    const dtos = await service.withTags([
      { ...base, id } as MediaAsset,
      { ...base, id: otro } as MediaAsset,
    ]);

    expect(dtos.map((d) => d.tags)).toEqual([['BEFORE'], ['AFTER']]);
  });

  it('un lote vacío no consulta etiquetas', async () => {
    const { service, tags } = servicio(base);

    expect(await service.withTags([])).toEqual([]);
    expect(tags.find).not.toHaveBeenCalled();
  });

  it('el dto conserva los campos del asset, no solo las etiquetas', async () => {
    const { service } = servicio(base, [{ assetId: id, tag: 'BEFORE' }]);

    const dto = await service.getWithTags(id);

    expect(dto).toMatchObject({ id, kind: 'PHOTO', visibility: 'INTERNAL' });
  });
});
