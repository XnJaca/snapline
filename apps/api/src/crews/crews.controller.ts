import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { CrewsService } from './crews.service';
import { AddCrewMemberDto, CreateCrewDto, UpdateCrewDto } from './dto/crew.dto';
import { Crew } from './entities/crew.entity';
import { CrewMember } from './entities/crew-member.entity';

@Controller('crews')
export class CrewsController {
  constructor(private readonly service: CrewsService) {}

  @RequirePermission('crews.read')
  @Get()
  list(): Promise<Crew[]> {
    return this.service.list();
  }

  @RequirePermission('crews.read')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string): Promise<Crew> {
    return this.service.get(id);
  }

  @RequirePermission('crews.write')
  @Post()
  create(@Body() dto: CreateCrewDto, @CurrentTenant() tenant: TenantContext): Promise<Crew> {
    return this.service.create(dto, tenant);
  }

  @RequirePermission('crews.write')
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCrewDto): Promise<Crew> {
    return this.service.update(id, dto);
  }

  @RequirePermission('crews.read')
  @Get(':id/members')
  members(@Param('id', ParseUUIDPipe) id: string): Promise<CrewMember[]> {
    return this.service.listMembers(id);
  }

  @RequirePermission('crews.write')
  @Post(':id/members')
  addMember(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AddCrewMemberDto, @CurrentTenant() tenant: TenantContext): Promise<CrewMember> {
    return this.service.addMember(id, dto, tenant);
  }

  @RequirePermission('crews.write')
  @Post(':id/members/:memberId/end')
  @HttpCode(200)
  endMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Body() body: { toDate: string },
  ): Promise<CrewMember> {
    return this.service.endMembership(id, memberId, body.toDate);
  }
}
