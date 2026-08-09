import { BadRequestException } from '@nestjs/common';
import { computeTotals, resolveLines } from './document-lines';
import { ServiceItem } from '../catalog/entities/service-item.entity';

const item = (over: Partial<ServiceItem> = {}): ServiceItem => ({
  id: 'item-1',
  name: 'Reemplazo de teja',
  description: 'asfáltica',
  unit: 'SQFT',
  unitPriceCents: 450,
  costCents: 210,
  taxable: false,
  category: null,
  active: true,
} as ServiceItem);

const catalog = (i: ServiceItem) => new Map([[i.id, i]]);

describe('resolveLines', () => {
  it('copia nombre, unidad y precio del catálogo en la línea', () => {
    const [line] = resolveLines([{ serviceItemId: 'item-1', qty: 200 }], catalog(item()));

    expect(line.nameSnapshot).toBe('Reemplazo de teja');
    expect(line.unitSnapshot).toBe('SQFT');
    expect(line.unitPriceCentsSnapshot).toBe(450);
    expect(line.amountCents).toBe(90_000);
    expect(line.serviceItemId).toBe('item-1');
  });

  it('un cambio posterior de precio no toca la línea ya resuelta', () => {
    const catalogo = catalog(item());
    const [antes] = resolveLines([{ serviceItemId: 'item-1', qty: 10 }], catalogo);

    catalogo.get('item-1')!.unitPriceCents = 540;
    const [despues] = resolveLines([{ serviceItemId: 'item-1', qty: 10 }], catalogo);

    expect(antes.unitPriceCentsSnapshot).toBe(450);
    expect(despues.unitPriceCentsSnapshot).toBe(540);
  });

  it('acepta líneas libres sin ítem del catálogo', () => {
    const [line] = resolveLines(
      [{ name: 'Retiro de escombros', qty: 1, unitPriceCentsOverride: 35_000 }],
      new Map(),
    );
    expect(line.serviceItemId).toBeNull();
    expect(line.amountCents).toBe(35_000);
  });

  it('rechaza una línea sin nombre ni ítem', () => {
    expect(() => resolveLines([{ qty: 1, unitPriceCentsOverride: 100 }], new Map()))
      .toThrow(BadRequestException);
  });

  it('rechaza una línea sin precio', () => {
    expect(() => resolveLines([{ name: 'Algo', qty: 1 }], new Map()))
      .toThrow(BadRequestException);
  });

  it('rechaza un ítem que no existe', () => {
    expect(() => resolveLines([{ serviceItemId: 'fantasma', qty: 1 }], new Map()))
      .toThrow(BadRequestException);
  });
});

describe('computeTotals', () => {
  it('el impuesto solo aplica sobre las líneas gravables', () => {
    const lines = resolveLines(
      [
        { serviceItemId: 'item-1', qty: 100 },
        { name: 'Materiales', qty: 1, unitPriceCentsOverride: 50_000 },
      ],
      catalog(item({ taxable: true } as Partial<ServiceItem>)),
    );
    lines[0].taxableSnapshot = true;
    lines[1].taxableSnapshot = false;

    const totals = computeTotals(lines, 600); // 6%

    expect(totals.subtotalCents).toBe(95_000);
    expect(totals.taxCents).toBe(2_700); // 6% de 45.000, no de 95.000
    expect(totals.totalCents).toBe(97_700);
  });

  it('sin tasa configurada el impuesto es cero', () => {
    const lines = resolveLines([{ name: 'x', qty: 2, unitPriceCentsOverride: 1_000 }], new Map());
    expect(computeTotals(lines, 0)).toEqual({
      subtotalCents: 2_000, taxCents: 0, totalCents: 2_000,
    });
  });

  it('todo el cálculo queda en enteros de centavos', () => {
    const lines = resolveLines([{ name: 'x', qty: 3, unitPriceCentsOverride: 333 }], new Map());
    const totals = computeTotals(lines, 725);
    for (const v of Object.values(totals)) expect(Number.isInteger(v)).toBe(true);
  });
});
