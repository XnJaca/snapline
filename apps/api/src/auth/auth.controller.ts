import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthResultDto } from './dto/auth-result.dto';
import { SessionDto } from './dto/session.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { Public } from './decorators/public.decorator';
import { RequirePermission } from './decorators/require-permission.decorator';
import { CurrentTenant } from './decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { ApiOkResponse } from '@nestjs/swagger';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(200)
  @ApiOkResponse({ type: AuthResultDto })
  login(@Body() dto: LoginDto): Promise<AuthResultDto> {
    return this.auth.login(dto.identifier, dto.password);
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  @ApiOkResponse({ type: AuthResultDto })
  refresh(@Body() dto: RefreshDto): Promise<AuthResultDto> {
    return this.auth.refresh(dto.refreshToken);
  }

  @RequirePermission('projects.read')
  @Get('me')
  @ApiOkResponse({ type: SessionDto })
  me(@CurrentTenant() tenant: TenantContext): SessionDto {
    return tenant;
  }
}
