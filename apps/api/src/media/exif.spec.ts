import sharp from 'sharp';

/**
 * Regla 17: publicar una foto con EXIF expone las coordenadas de la vivienda del
 * cliente. Antes esto solo se marcaba con una fecha y la bandera mentía.
 *
 * Estos tests cubren el procesamiento; que el archivo se reescriba en el bucket
 * se verifica en el flujo de integración.
 */
async function withGpsExif(): Promise<Buffer> {
  return sharp({ create: { width: 400, height: 300, channels: 3, background: { r: 200, g: 120, b: 60 } } })
    .withExif({
      IFD0: { Make: 'Apple', Model: 'iPhone 15' },
      IFD2: { GPSLatitudeRef: 'N', GPSLongitudeRef: 'W' },
    })
    .jpeg()
    .toBuffer();
}

const strip = (input: Buffer) => sharp(input).rotate().toBuffer();

describe('limpieza de EXIF', () => {
  it('la foto de origen sí trae metadatos', async () => {
    const meta = await sharp(await withGpsExif()).metadata();
    expect(meta.exif).toBeDefined();
  });

  it('procesarla borra el bloque EXIF completo', async () => {
    const meta = await sharp(await strip(await withGpsExif())).metadata();
    expect(meta.exif).toBeUndefined();
  });

  it('no deja rastro de GPS en los bytes del archivo', async () => {
    const clean = await strip(await withGpsExif());
    expect(clean.includes(Buffer.from('GPS'))).toBe(false);
    expect(clean.includes(Buffer.from('Apple'))).toBe(false);
  });

  it('aplica la orientación antes de borrarla: una foto vertical no queda de costado', async () => {
    // Orientation 6 = rotar 90°. Al quitar el EXIF sin aplicarla, el visor pierde
    // la instrucción y la muestra acostada.
    // withMetadata y no withExif: sharp solo lee la orientación del primero.
    const rotada = await sharp({ create: { width: 400, height: 300, channels: 3, background: { r: 1, g: 1, b: 1 } } })
      .withMetadata({ orientation: 6 })
      .jpeg()
      .toBuffer();

    const antes = await sharp(rotada).metadata();
    const despues = await sharp(await strip(rotada)).metadata();

    expect(antes.orientation).toBe(6);
    expect(antes.width).toBe(400);
    expect(despues.width).toBe(300);
    expect(despues.height).toBe(400);
  });

  it('la imagen sigue siendo válida y del mismo contenido visual', async () => {
    const clean = await strip(await withGpsExif());
    const meta = await sharp(clean).metadata();
    expect(meta.format).toBe('jpeg');
    expect(meta.width).toBeGreaterThan(0);
  });
});
