import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Customer } from './entities/customer.entity';
import { Site } from './entities/site.entity';
import { CreateCustomerDto, SiteInputDto, UpdateCustomerDto } from './dto/customer.dto';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer) private readonly customers: Repository<Customer>,
    @InjectRepository(Site) private readonly sites: Repository<Site>,
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

  async remove(id: string): Promise<void> {
    await this.get(id);
    await this.customers.update({ id }, { deletedAt: new Date() });
  }

  listSites(customerId: string): Promise<Site[]> {
    return this.sites.find({ where: { customer: { id: customerId }, deletedAt: IsNull() } });
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

  // Otorgar el release habilita publicar; revocarlo debe despublicar en cascada.
  async setPhotoRelease(id: string, granted: boolean, documentId?: string): Promise<Customer> {
    await this.get(id);
    await this.customers.update({ id }, {
      photoReleaseGrantedAt: granted ? new Date() : null,
      photoReleaseDocumentId: granted ? (documentId ?? null) : null,
    });
    return this.get(id);
  }
}
