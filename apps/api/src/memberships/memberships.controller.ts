import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiOkResponse } from '@nestjs/swagger';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { MembershipsService } from './memberships.service';
import { CreateMemberDto, MemberDto, MemberWithInviteDto, UpdateMemberDto } from './dto/membership.dto';

// Todo acá cuelga de members.manage —OWNER y ADMIN—: es el único camino por el
// que sale pay_rate_cents.
@Controller('memberships')
export class MembershipsController {
  constructor(private readonly service: MembershipsService) {}

  @RequirePermission('members.manage')
  @Get()
  @ApiOkResponse({ type: [MemberDto] })
  list(): Promise<MemberDto[]> {
    return this.service.list();
  }

  @RequirePermission('members.manage')
  @Get(':id')
  @ApiOkResponse({ type: MemberDto })
  get(@Param('id', ParseUUIDPipe) id: string): Promise<MemberDto> {
    return this.service.get(id);
  }

  @RequirePermission('members.manage')
  @Post()
  @ApiOkResponse({ type: MemberWithInviteDto })
  create(@Body() dto: CreateMemberDto, @CurrentTenant() tenant: TenantContext): Promise<MemberWithInviteDto> {
    return this.service.create(dto, tenant);
  }

  @RequirePermission('members.manage')
  @Patch(':id')
  @ApiOkResponse({ type: MemberDto })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateMemberDto): Promise<MemberDto> {
    return this.service.update(id, dto);
  }

  @RequirePermission('members.manage')
  @Post(':id/invite')
  @HttpCode(200)
  @ApiOkResponse({ type: MemberWithInviteDto })
  invite(@Param('id', ParseUUIDPipe) id: string): Promise<MemberWithInviteDto> {
    return this.service.regenerateInvite(id);
  }

  @RequirePermission('members.manage')
  @Post(':id/deactivate')
  @HttpCode(200)
  @ApiOkResponse({ type: MemberDto })
  deactivate(@Param('id', ParseUUIDPipe) id: string): Promise<MemberDto> {
    return this.service.deactivate(id);
  }
}
