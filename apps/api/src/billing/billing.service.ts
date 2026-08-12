import { ApiError } from '../common/errors/api-error';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, IsNull, Repository } from 'typeorm';
import { InjectDataSource } from '@nestjs/typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { ServiceItem } from '../catalog/entities/service-item.entity';
import { TaxRate } from '../catalog/entities/tax-rate.entity';
import { Estimate } from './entities/estimate.entity';
import { EstimateLine } from './entities/estimate-line.entity';
import { Invoice } from './entities/invoice.entity';
import { InvoiceLine } from './entities/invoice-line.entity';
import { Payment } from './entities/payment.entity';
import { AcceptEstimateDto, CreateEstimateDto, DocumentLineDto } from './dto/estimate.dto';
import { CreateInvoiceDto, InvoiceFromEstimateDto, RecordPaymentDto, VoidInvoiceDto } from './dto/invoice.dto';
import { computeTotals, resolveLines } from './document-lines';

@Injectable()
export class BillingService {
  constructor(
    @InjectRepository(Estimate) private readonly estimates: Repository<Estimate>,
    @InjectRepository(EstimateLine) private readonly estimateLines: Repository<EstimateLine>,
    @InjectRepository(Invoice) private readonly invoices: Repository<Invoice>,
    @InjectRepository(InvoiceLine) private readonly invoiceLines: Repository<InvoiceLine>,
    @InjectRepository(Payment) private readonly payments: Repository<Payment>,
    @InjectRepository(ServiceItem) private readonly items: Repository<ServiceItem>,
    @InjectRepository(TaxRate) private readonly taxRates: Repository<TaxRate>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  // ----------------------------------------------------------- estimados

  listEstimates(): Promise<Estimate[]> {
    return this.estimates.find({
      where: { deletedAt: IsNull() }, relations: { customer: true }, order: { createdAt: 'DESC' },
    });
  }

  async getEstimate(id: string): Promise<Estimate> {
    const found = await this.estimates.findOne({
      where: { id, deletedAt: IsNull() },
      relations: { customer: true, lines: true },
      order: { lines: { position: 'ASC' } },
    });
    if (!found) throw new NotFoundException('Estimado no encontrado');
    return found;
  }

  @Transactional()
  async createEstimate(dto: CreateEstimateDto, tenant: TenantContext): Promise<Estimate> {
    const lines = await this.buildLines(dto.lines);
    const totals = computeTotals(lines, await this.currentTaxRateBps());
    const id = dto.id ?? newId();

    await this.estimates.save(this.estimates.create({
      id,
      companyId: tenant.companyId,
      customer: { id: dto.customerId } as Estimate['customer'],
      project: dto.projectId ? ({ id: dto.projectId } as Estimate['project']) : null,
      number: null,
      status: 'DRAFT',
      issuedAt: null,
      expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
      terms: dto.terms ?? null,
      acceptedAt: null,
      acceptedSignatureAssetId: null,
      acceptedIp: null,
      deletedAt: null,
      ...totals,
    }));

    await this.estimateLines.save(lines.map((l) => this.estimateLines.create({
      ...l, id: newId(), companyId: tenant.companyId,
      estimate: { id } as EstimateLine['estimate'],
      serviceItem: l.serviceItemId ? ({ id: l.serviceItemId } as EstimateLine['serviceItem']) : null,
    })));

    return this.getEstimate(id);
  }

  // La numeración la asigna el servidor al enviar, con lock de fila.
  @Transactional()
  async sendEstimate(id: string, tenant: TenantContext): Promise<Estimate> {
    const estimate = await this.getEstimate(id);
    if (estimate.status !== 'DRAFT') throw ApiError.conflict('ESTIMATE_ALREADY_SENT', 'El estimado ya fue enviado');

    const number = await this.nextNumber('ESTIMATE', tenant.companyId);
    await this.estimates.update({ id }, {
      status: 'SENT', number: `EST-${String(number).padStart(5, '0')}`, issuedAt: new Date(),
    });
    return this.getEstimate(id);
  }

  @Transactional()
  async acceptEstimate(id: string, dto: AcceptEstimateDto, ip: string | null): Promise<Estimate> {
    const estimate = await this.getEstimate(id);
    if (!['SENT', 'VIEWED'].includes(estimate.status)) {
      throw new ConflictException(`No se puede aceptar un estimado en estado ${estimate.status}`);
    }
    if (estimate.expiresAt && estimate.expiresAt < new Date()) {
      await this.estimates.update({ id }, { status: 'EXPIRED' });
      throw new ConflictException('El estimado venció');
    }
    await this.estimates.update({ id }, {
      status: 'ACCEPTED',
      acceptedAt: new Date(),
      acceptedSignatureAssetId: dto.signatureAssetId ?? null,
      acceptedIp: ip,
    });
    return this.getEstimate(id);
  }

  // ------------------------------------------------------------ facturas

  listInvoices(): Promise<Invoice[]> {
    return this.invoices.find({
      where: { deletedAt: IsNull() }, relations: { customer: true }, order: { createdAt: 'DESC' },
    });
  }

  async getInvoice(id: string): Promise<Invoice> {
    const found = await this.invoices.findOne({
      where: { id, deletedAt: IsNull() },
      relations: { customer: true, lines: true },
      order: { lines: { position: 'ASC' } },
    });
    if (!found) throw new NotFoundException('Factura no encontrada');
    return found;
  }

  @Transactional()
  async createInvoice(dto: CreateInvoiceDto, tenant: TenantContext): Promise<Invoice> {
    const lines = await this.buildLines(dto.lines);
    const totals = computeTotals(lines, await this.currentTaxRateBps());
    return this.persistInvoice({
      id: dto.id ?? newId(),
      customerId: dto.customerId,
      projectId: dto.projectId ?? null,
      estimateId: null,
      dueAt: dto.dueAt ? new Date(dto.dueAt) : null,
      lines, totals, tenant,
    });
  }

  // Copia las líneas ya congeladas del estimado: no vuelve a leer el catálogo.
  @Transactional()
  async invoiceFromEstimate(estimateId: string, dto: InvoiceFromEstimateDto, tenant: TenantContext): Promise<Invoice> {
    const estimate = await this.getEstimate(estimateId);
    if (estimate.status !== 'ACCEPTED') {
      throw ApiError.conflict('ESTIMATE_NOT_ACCEPTED', 'Solo se factura un estimado aceptado');
    }
    const existing = await this.invoices.findOne({
      where: { estimate: { id: estimateId }, deletedAt: IsNull() },
    });
    if (existing) throw ApiError.conflict('ESTIMATE_ALREADY_INVOICED', 'Ese estimado ya tiene factura');

    const lines = estimate.lines.map((l) => ({
      position: l.position,
      serviceItemId: l.serviceItemId,
      nameSnapshot: l.nameSnapshot,
      descriptionSnapshot: l.descriptionSnapshot,
      unitSnapshot: l.unitSnapshot,
      taxableSnapshot: l.taxableSnapshot,
      unitPriceCentsSnapshot: l.unitPriceCentsSnapshot,
      qty: l.qty,
      amountCents: l.amountCents,
    }));

    return this.persistInvoice({
      id: newId(),
      customerId: estimate.customerId,
      projectId: estimate.projectId,
      estimateId,
      dueAt: dto.dueAt ? new Date(dto.dueAt) : null,
      lines,
      totals: {
        subtotalCents: estimate.subtotalCents,
        taxCents: estimate.taxCents,
        totalCents: estimate.totalCents,
      },
      tenant,
    });
  }

  @Transactional()
  async sendInvoice(id: string, tenant: TenantContext): Promise<Invoice> {
    const invoice = await this.getInvoice(id);
    if (invoice.status !== 'DRAFT') throw new ConflictException('La factura ya fue enviada');

    const number = await this.nextNumber('INVOICE', tenant.companyId);
    await this.invoices.update({ id }, {
      status: 'SENT', number: `INV-${String(number).padStart(5, '0')}`, issuedAt: new Date(),
    });
    return this.getInvoice(id);
  }

  @Transactional()
  async recordPayment(invoiceId: string, dto: RecordPaymentDto, tenant: TenantContext): Promise<Invoice> {
    const invoice = await this.getInvoice(invoiceId);
    if (invoice.status === 'DRAFT') throw ApiError.conflict('INVOICE_NOT_SENT', 'La factura todavía no fue enviada');
    if (invoice.status === 'VOID') throw ApiError.conflict('INVOICE_VOIDED', 'La factura está anulada');

    if (dto.idempotencyKey) {
      const seen = await this.payments.findOne({ where: { idempotencyKey: dto.idempotencyKey } });
      if (seen) return this.getInvoice(invoiceId);
    }
    if (dto.amountCents > invoice.balanceCents) {
      throw ApiError.badRequest('PAYMENT_EXCEEDS_BALANCE',
        `El pago (${dto.amountCents}) excede el saldo (${invoice.balanceCents})`);
    }

    await this.payments.save(this.payments.create({
      id: newId(),
      companyId: tenant.companyId,
      invoice: { id: invoiceId } as Payment['invoice'],
      amountCents: dto.amountCents,
      method: dto.method,
      receivedAt: new Date(dto.receivedAt),
      reference: dto.reference ?? null,
      recordedBy: { id: tenant.membershipId } as Payment['recordedBy'],
      idempotencyKey: dto.idempotencyKey ?? null,
      deletedAt: null,
    }));

    // El saldo es derivado: se recalcula desde los pagos, no se edita.
    const balanceCents = invoice.totalCents - (await this.paidTotal(invoiceId));
    await this.invoices.update({ id: invoiceId }, {
      balanceCents,
      status: balanceCents === 0 ? 'PAID' : 'PARTIAL',
    });
    return this.getInvoice(invoiceId);
  }

  // Una factura enviada no se edita: se anula y se emite otra.
  // `_dto.reason` se exige y hoy no se guarda: no hay dónde. Ver DEBT-0006.
  @Transactional()
  async voidInvoice(id: string, _dto: VoidInvoiceDto): Promise<Invoice> {
    const invoice = await this.getInvoice(id);
    if (invoice.status === 'PAID') throw new ConflictException('No se anula una factura pagada');
    if (invoice.status === 'VOID') throw new ConflictException('Ya está anulada');
    await this.invoices.update({ id }, { status: 'VOID', voidedAt: new Date(), balanceCents: 0 });
    return this.getInvoice(id);
  }

  listPayments(invoiceId: string): Promise<Payment[]> {
    return this.payments.find({
      where: { invoice: { id: invoiceId }, deletedAt: IsNull() }, order: { receivedAt: 'ASC' },
    });
  }

  // ------------------------------------------------------------ internos

  private async persistInvoice(args: {
    id: string; customerId: string; projectId: string | null; estimateId: string | null;
    dueAt: Date | null; lines: ReturnType<typeof resolveLines>;
    totals: ReturnType<typeof computeTotals>; tenant: TenantContext;
  }): Promise<Invoice> {
    await this.invoices.save(this.invoices.create({
      id: args.id,
      companyId: args.tenant.companyId,
      customer: { id: args.customerId } as Invoice['customer'],
      project: args.projectId ? ({ id: args.projectId } as Invoice['project']) : null,
      estimate: args.estimateId ? ({ id: args.estimateId } as Invoice['estimate']) : null,
      number: null,
      status: 'DRAFT',
      issuedAt: null,
      dueAt: args.dueAt,
      voidedAt: null,
      deletedAt: null,
      ...args.totals,
      balanceCents: args.totals.totalCents,
    }));

    await this.invoiceLines.save(args.lines.map((l) => this.invoiceLines.create({
      ...l, id: newId(), companyId: args.tenant.companyId,
      invoice: { id: args.id } as InvoiceLine['invoice'],
      serviceItem: l.serviceItemId ? ({ id: l.serviceItemId } as InvoiceLine['serviceItem']) : null,
    })));

    return this.getInvoice(args.id);
  }

  private async buildLines(dtos: DocumentLineDto[]) {
    const ids = dtos.map((l) => l.serviceItemId).filter((v): v is string => !!v);
    const items = ids.length
      ? await this.items.find({ where: { id: In(ids), deletedAt: IsNull() } })
      : [];
    return resolveLines(dtos, new Map(items.map((i) => [i.id, i])));
  }

  private async currentTaxRateBps(): Promise<number> {
    const rate = await this.taxRates.findOne({ where: { active: true, deletedAt: IsNull() } });
    return rate?.rateBps ?? 0;
  }

  private async paidTotal(invoiceId: string): Promise<number> {
    const rows = await this.payments.find({ where: { invoice: { id: invoiceId }, deletedAt: IsNull() } });
    return rows.reduce((sum, p) => sum + p.amountCents, 0);
  }

  private async nextNumber(docType: 'ESTIMATE' | 'INVOICE', companyId: string): Promise<number> {
    const [row] = await this.dataSource.query<{ next_document_number: string }[]>(
      'SELECT next_document_number($1, $2)', [companyId, docType],
    );
    return Number(row.next_document_number);
  }
}
