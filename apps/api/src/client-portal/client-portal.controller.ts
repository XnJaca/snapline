import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiOkResponse, ApiCreatedResponse } from '@nestjs/swagger';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { StrictThrottle } from '../common/throttle/strict-throttle.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { ClientPortalService } from './client-portal.service';
import {
  ClientProjectViewDto, GrantAccessDto, GrantAccessResultDto, RequestOfferDto,
} from './dto/client-portal.dto';

@Controller('client-access')
export class ClientAccessController {
  constructor(private readonly service: ClientPortalService) {}

  @RequirePermission('customers.write')
  @Post()
  @ApiCreatedResponse({ type: GrantAccessResultDto })
  grant(@Body() dto: GrantAccessDto, @CurrentTenant() tenant: TenantContext): Promise<GrantAccessResultDto> {
    return this.service.grant(dto, tenant, process.env.CLIENT_PORTAL_URL ?? 'http://localhost:4200');
  }

  @RequirePermission('customers.write')
  @Delete(':id')
  @HttpCode(204)
  revoke(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.service.revoke(id);
  }
}

/** Anónimo: el token del link es la única credencial. */
@Controller('p')
export class ClientPortalController {
  constructor(private readonly service: ClientPortalService) {}

  @Public()
  @StrictThrottle()
  @Get(':token')
  @ApiOkResponse({ type: [ClientProjectViewDto] })
  view(@Param('token') token: string): Promise<ClientProjectViewDto[]> {
    return this.service.view(token);
  }

  @Public()
  @StrictThrottle()
  @Post(':token/offers')
  requestOffer(@Param('token') token: string, @Body() dto: RequestOfferDto): Promise<{ leadId: string }> {
    return this.service.requestOffer(token, dto);
  }
}
