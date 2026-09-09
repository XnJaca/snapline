import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { CrewsService } from './crews.service';
import { ApiOkResponse } from '@nestjs/swagger';
import {
  AddCrewMemberDto, CreateCrewDto, CrewAssignmentDto, CrewDto, CrewMemberDto,
  EndCrewMemberDto, UpdateCrewDto,
} from './dto/crew.dto';
import { CrewMember } from './entities/crew-member.entity';

@Controller('crews')
export class CrewsController {
  constructor(private readonly service: CrewsService) {}

  @RequirePermission('crews.read')
  @Get()
  @ApiOkResponse({ type: [CrewDto] })
  list(@CurrentTenant() tenant: TenantContext): Promise<CrewDto[]> {
    return this.service.list(tenant);
  }

  @RequirePermission('crews.read')
  @Get(':id')
  @ApiOkResponse({ type: CrewDto })
  get(@Param('id', ParseUUIDPipe) id: string, @CurrentTenant() tenant: TenantContext): Promise<CrewDto> {
    return this.service.get(id, tenant);
  }

  @RequirePermission('crews.write')
  @Post()
  @ApiOkResponse({ type: CrewDto })
  create(@Body() dto: CreateCrewDto, @CurrentTenant() tenant: TenantContext): Promise<CrewDto> {
    return this.service.create(dto, tenant);
  }

  @RequirePermission('crews.write')
  @Patch(':id')
  @ApiOkResponse({ type: CrewDto })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCrewDto, @CurrentTenant() tenant: TenantContext): Promise<CrewDto> {
    return this.service.update(id, dto, tenant);
  }

  @RequirePermission('crews.read')
  @Get(':id/members')
  @ApiOkResponse({ type: [CrewMemberDto] })
  members(@Param('id', ParseUUIDPipe) id: string, @CurrentTenant() tenant: TenantContext): Promise<CrewMemberDto[]> {
    return this.service.listMembers(id, tenant);
  }

  @RequirePermission('crews.read')
  @Get(':id/assignments')
  @ApiOkResponse({ type: [CrewAssignmentDto] })
  assignments(@Param('id', ParseUUIDPipe) id: string, @CurrentTenant() tenant: TenantContext): Promise<CrewAssignmentDto[]> {
    return this.service.listAssignments(id, tenant);
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
    @Body() dto: EndCrewMemberDto,
    @CurrentTenant() tenant: TenantContext,
  ): Promise<CrewMember> {
    return this.service.endMembership(id, memberId, dto.toDate, tenant);
  }
}
