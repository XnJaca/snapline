import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { ServiceItem } from './entities/service-item.entity';
import { CreateServiceItemDto, UpdateServiceItemDto } from './dto/service-item.dto';

@Injectable()
export class CatalogService {
  constructor(
    @InjectRepository(ServiceItem) private readonly items: Repository<ServiceItem>,
  ) {}

  list(includeInactive = false): Promise<ServiceItem[]> {
    return this.items.find({
      where: { deletedAt: IsNull(), ...(includeInactive ? {} : { active: true }) },
      order: { category: 'ASC', name: 'ASC' },
    });
  }

  async get(id: string): Promise<ServiceItem> {
    const found = await this.items.findOne({ where: { id, deletedAt: IsNull() } });
    if (!found) throw new NotFoundException('Ítem no encontrado');
    return found;
  }

  async create(dto: CreateServiceItemDto, tenant: TenantContext): Promise<ServiceItem> {
    const item = this.items.create({
      ...dto,
      id: dto.id ?? newId(),
      companyId: tenant.companyId,
      taxable: dto.taxable ?? false,
      active: true,
      deletedAt: null,
    });
    return this.items.save(item);
  }

  async update(id: string, dto: UpdateServiceItemDto): Promise<ServiceItem> {
    await this.get(id);
    await this.items.update({ id }, dto);
    return this.get(id);
  }

  // Se desactiva, no se borra: puede estar referenciado en documentos ya emitidos.
  async deactivate(id: string): Promise<ServiceItem> {
    await this.get(id);
    await this.items.update({ id }, { active: false });
    return this.get(id);
  }
}
