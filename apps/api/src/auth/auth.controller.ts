import { Body, Controller, Get, HttpCode, Patch, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthResultDto, AuthUserDto } from './dto/auth-result.dto';
import { UpdateLocaleDto } from './dto/update-locale.dto';
import { SessionDto } from './dto/session.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { Public } from './decorators/public.decorator';
import { RequirePermission } from './decorators/require-permission.decorator';
import { CurrentTenant } from './decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { ApiOkResponse } from '@nestjs/swagger';
import { StrictThrottle } from '../common/throttle/strict-throttle.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @StrictThrottle()
  @Post('login')
  @HttpCode(200)
  @ApiOkResponse({ type: AuthResultDto })
  login(@Body() dto: LoginDto): Promise<AuthResultDto> {
    return this.auth.login(dto.identifier, dto.password);
  }

  @Public()
  @StrictThrottle()
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

  /**
   * El idioma de quien está en sesión. El id sale del token, así que no hay
   * forma de cambiarle el idioma a otra persona.
   */
  @RequirePermission('profile.write')
  @Patch('me/locale')
  @ApiOkResponse({ type: AuthUserDto })
  updateLocale(
    @CurrentTenant() tenant: TenantContext,
    @Body() dto: UpdateLocaleDto,
  ): Promise<AuthUserDto> {
    return this.auth.updateLocale(tenant.userId, dto.locale);
  }
}
