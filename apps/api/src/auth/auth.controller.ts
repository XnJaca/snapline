import { Body, Controller, Get, HttpCode, Patch, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthResultDto, AuthUserDto } from './dto/auth-result.dto';
import { UpdateLocaleDto } from './dto/update-locale.dto';
import { SessionDto } from './dto/session.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { CheckInviteDto, RedeemInviteDto, VerifyInviteDto } from '../memberships/dto/membership.dto';
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

  /// Comprueba el código antes de pedir la contraseña. No lo consume, pero un
  /// fallo gasta intento igual que el canje: si no, sería probar códigos gratis.
  @Public()
  @StrictThrottle()
  @Post('invite/verify')
  @HttpCode(200)
  @ApiOkResponse({ type: VerifyInviteDto })
  verifyInvite(@Body() dto: CheckInviteDto): Promise<VerifyInviteDto> {
    return this.auth.verifyInvite(dto.identifier, dto.code);
  }

  // Acepta credenciales sin autenticación previa, como login y refresh.
  @Public()
  @StrictThrottle()
  @Post('invite/redeem')
  @HttpCode(200)
  @ApiOkResponse({ type: AuthResultDto })
  redeemInvite(@Body() dto: RedeemInviteDto): Promise<AuthResultDto> {
    return this.auth.redeemInvite(dto.identifier, dto.code, dto.password);
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
