import { BadRequestException } from '@nestjs/common';
import { ServiceItem, ServiceUnit } from '../catalog/entities/service-item.entity';
import { DocumentLineDto } from './dto/estimate.dto';

export interface ResolvedLine {
  position: number;
  serviceItemId: string | null;
  nameSnapshot: string;
  descriptionSnapshot: string | null;
  unitSnapshot: ServiceUnit;
  taxableSnapshot: boolean;
  unitPriceCentsSnapshot: number;
  qty: number;
  amountCents: number;
}

export interface Totals {
  subtotalCents: number;
  taxCents: number;
  totalCents: number;
}

/**
 * Copia del catálogo al momento de emitir. La línea guarda su propio nombre y
 * precio: referenciar el catálogo vivo reescribiría documentos ya emitidos.
 */
export function resolveLines(dtos: DocumentLineDto[], catalog: Map<string, ServiceItem>): ResolvedLine[] {
  return dtos.map((line, i) => {
    const item = line.serviceItemId ? catalog.get(line.serviceItemId) : undefined;
    if (line.serviceItemId && !item) {
      throw new BadRequestException(`El ítem ${line.serviceItemId} no existe en el catálogo`);
    }
    const name = line.name ?? item?.name;
    if (!name) throw new BadRequestException('Cada línea necesita un ítem del catálogo o un nombre');

    const unitPriceCents = line.unitPriceCentsOverride ?? item?.unitPriceCents;
    if (unitPriceCents === undefined) {
      throw new BadRequestException(`La línea "${name}" no tiene precio`);
    }

    return {
      position: i,
      serviceItemId: item?.id ?? null,
      nameSnapshot: name,
      descriptionSnapshot: line.description ?? item?.description ?? null,
      unitSnapshot: item?.unit ?? 'EACH',
      taxableSnapshot: item?.taxable ?? false,
      unitPriceCentsSnapshot: unitPriceCents,
      qty: line.qty,
      amountCents: Math.round(unitPriceCents * line.qty),
    };
  });
}

/** Se calcula en el servidor. Nunca se guarda un total que mandó el cliente. */
export function computeTotals(lines: ResolvedLine[], taxRateBps: number): Totals {
  const subtotalCents = lines.reduce((sum, l) => sum + l.amountCents, 0);
  const taxableBase = lines.filter((l) => l.taxableSnapshot).reduce((s, l) => s + l.amountCents, 0);
  const taxCents = Math.round((taxableBase * taxRateBps) / 10_000);
  return { subtotalCents, taxCents, totalCents: subtotalCents + taxCents };
}
