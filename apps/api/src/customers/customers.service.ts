import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, IsNull, Repository } from 'typeorm';
import { ApiError } from '../common/errors/api-error';
import { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Customer } from './entities/customer.entity';
import { Site } from './entities/site.entity';
import { CreateCustomerDto, SiteInputDto, UpdateCustomerDto, UpdateSiteDto } from './dto/customer.dto';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer) private readonly customers: Repository<Customer>,
    @InjectRepository(Site) private readonly sites: Repository<Site>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  list(): Promise<Customer[]> {
    return this.customers.find({ where: { deletedAt: IsNull() }, order: { displayName: 'ASC' } });
  }

  async get(id: string): Promise<Customer> {
    const found = await this.customers.findOne({ where: { id, deletedAt: IsNull() } });
    if (!found) throw new NotFoundException('Cliente no encontrado');
    return found;
  }

  @Transactional()
  async create(dto: CreateCustomerDto, tenant: TenantContext): Promise<Customer> {
    const id = dto.id ?? newId();
    if (dto.id && (await this.customers.findOne({ where: { id } }))) {
      throw new ConflictException('Ya existe un cliente con ese id');
    }
    const customer = this.customers.create({
      ...dto, id, companyId: tenant.companyId, deletedAt: null,
    });
    await this.customers.save(customer);
    if (dto.site) await this.addSite(id, dto.site, tenant);
    return this.get(id);
  }

  @Transactional()
  async update(id: string, dto: UpdateCustomerDto): Promise<Customer> {
    await this.get(id);
    const { site: _site, id: _id, ...rest } = dto;
    // Cast: QueryDeepPartialEntity no resuelve bien las columnas jsonb.
    await this.customers.update({ id }, rest as QueryDeepPartialEntity<Customer>);
    return this.get(id);
  }

  /**
   * Las propiedades se van con el cliente: lo hace el trigger
   * `customer_sites_cascade_delete`, no este método.
   *
   * La comprobación de historia está duplicada a propósito. La que manda es la
   * de la base (`enforce_customer_no_history`, migración `CustomerDeleteGuards`),
   * que ningún camino se puede saltar; esta atrapa el caso común sin depender de
   * matchear el texto de una excepción de Postgres.
   */
  @Transactional()
  async remove(id: string): Promise<void> {
    await this.get(id);

    const [historia] = await this.dataSource.query<Array<{ obras: string; documentos: string }>>(
      `SELECT
         (SELECT count(*) FROM project
          WHERE customer_id = $1 AND deleted_at IS NULL) AS obras,
         (SELECT count(*) FROM estimate
          WHERE customer_id = $1 AND deleted_at IS NULL AND status <> 'DRAFT')
       + (SELECT count(*) FROM invoice
          WHERE customer_id = $1 AND deleted_at IS NULL AND status <> 'DRAFT') AS documentos`,
      [id],
    );

    if (Number(historia.obras) > 0 || Number(historia.documentos) > 0) {
      throw ApiError.conflict(
        'CUSTOMER_HAS_HISTORY',
        'Este cliente tiene obras o documentos y no se puede borrar',
      );
    }

    await this.customers.update({ id }, { deletedAt: new Date() });
  }

  /**
   * Exige que el cliente siga vivo. Sin eso, borrar un cliente dejaba su
   * dirección alcanzable por acá indefinidamente mientras el propio cliente ya
   * respondía 404.
   */
  listSites(customerId: string): Promise<Site[]> {
    return this.sites.find({
      where: { customer: { id: customerId, deletedAt: IsNull() }, deletedAt: IsNull() },
    });
  }

  /**
   * `customerId` se valida cuando viene: una ruta que dice de quién es la
   * propiedad no puede devolver la de otro cliente. Por la bandeja llega solo el
   * id de la propiedad, que es lo único que el dispositivo tiene.
   */
  async getSite(id: string, customerId?: string): Promise<Site> {
    const found = await this.sites.findOne({
      where: {
        id, deletedAt: IsNull(),
        ...(customerId ? { customer: { id: customerId, deletedAt: IsNull() } } : {}),
      },
    });
    if (!found) throw new NotFoundException('Propiedad no encontrada');
    return found;
  }

  @Transactional()
  async updateSite(id: string, dto: UpdateSiteDto, customerId?: string): Promise<Site> {
    await this.getSite(id, customerId);
    // Cast: QueryDeepPartialEntity no resuelve bien las columnas jsonb.
    await this.sites.update({ id }, dto as QueryDeepPartialEntity<Site>);
    return this.getSite(id);
  }

  async addSite(customerId: string, dto: SiteInputDto, tenant: TenantContext): Promise<Site> {
    await this.get(customerId);
    const site = this.sites.create({
      id: dto.id ?? newId(),
      companyId: tenant.companyId,
      customer: { id: customerId } as Site['customer'],
      address: dto.address,
      lat: dto.lat ?? null,
      lng: dto.lng ?? null,
      geofenceRadiusM: dto.geofenceRadiusM ?? null,
      deletedAt: null,
    });
    return this.sites.save(site);
  }

}
