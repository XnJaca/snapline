import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, QueryFailedError, Repository } from 'typeorm';
import { Transactional } from 'typeorm-transactional';
import { newId } from '../common/entities/base.entity';
import { TenantContext } from '../tenant/tenant-context';
import { Crew } from './entities/crew.entity';
import { CrewMember } from './entities/crew-member.entity';
import { AddCrewMemberDto, CreateCrewDto, UpdateCrewDto } from './dto/crew.dto';

@Injectable()
export class CrewsService {
  constructor(
    @InjectRepository(Crew) private readonly crews: Repository<Crew>,
    @InjectRepository(CrewMember) private readonly members: Repository<CrewMember>,
  ) {}

  list(): Promise<Crew[]> {
    return this.crews.find({ where: { deletedAt: IsNull() }, relations: { foreman: true } });
  }

  async get(id: string): Promise<Crew> {
    const found = await this.crews.findOne({
      where: { id, deletedAt: IsNull() }, relations: { foreman: true },
    });
    if (!found) throw new NotFoundException('Cuadrilla no encontrada');
    return found;
  }

  async create(dto: CreateCrewDto, tenant: TenantContext): Promise<Crew> {
    const crew = this.crews.create({
      id: dto.id ?? newId(),
      companyId: tenant.companyId,
      name: dto.name,
      foreman: dto.foremanMembershipId ? ({ id: dto.foremanMembershipId } as Crew['foreman']) : null,
      color: dto.color ?? null,
      deletedAt: null,
    });
    await this.crews.save(crew);
    return this.get(crew.id);
  }

  async update(id: string, dto: UpdateCrewDto): Promise<Crew> {
    await this.get(id);
    const { foremanMembershipId, ...rest } = dto;
    await this.crews.update({ id }, {
      ...rest,
      ...(foremanMembershipId ? { foreman: { id: foremanMembershipId } } : {}),
    });
    return this.get(id);
  }

  listMembers(crewId: string): Promise<CrewMember[]> {
    return this.members.find({
      where: { crew: { id: crewId }, deletedAt: IsNull() },
      relations: { membership: true },
      order: { fromDate: 'DESC' },
    });
  }

  @Transactional()
  async addMember(crewId: string, dto: AddCrewMemberDto, tenant: TenantContext): Promise<CrewMember> {
    await this.get(crewId);
    if (dto.toDate && dto.toDate < dto.fromDate) {
      throw new BadRequestException('La fecha de salida no puede ser anterior a la de entrada');
    }
    const member = this.members.create({
      id: newId(),
      companyId: tenant.companyId,
      crew: { id: crewId } as CrewMember['crew'],
      membership: { id: dto.membershipId } as CrewMember['membership'],
      fromDate: dto.fromDate,
      toDate: dto.toDate ?? null,
      deletedAt: null,
    });
    try {
      return await this.members.save(member);
    } catch (e) {
      // Constraint de exclusión: nadie puede estar en dos cuadrillas a la vez.
      if (e instanceof QueryFailedError && String(e.message).includes('crew_member_no_overlap')) {
        throw new ConflictException('Esa persona ya pertenece a una cuadrilla en ese rango de fechas');
      }
      throw e;
    }
  }

  async endMembership(crewId: string, memberId: string, toDate: string): Promise<CrewMember> {
    const member = await this.members.findOne({ where: { id: memberId, crew: { id: crewId } } });
    if (!member) throw new NotFoundException('Miembro no encontrado');
    await this.members.update({ id: memberId }, { toDate });
    return (await this.members.findOne({ where: { id: memberId } }))!;
  }
}
