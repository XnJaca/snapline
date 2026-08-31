import { Body, Controller, HttpCode, Post, Req, Res } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ApiNoContentResponse, ApiOkResponse } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { AuthResultDto } from './dto/auth-result.dto';
import { WebAuthResultDto } from './dto/web-auth-result.dto';
import { LoginDto } from './dto/login.dto';
import { Public } from './decorators/public.decorator';
import { StrictThrottle } from '../common/throttle/strict-throttle.decorator';
import {
  clearedRefreshCookie,
  cookieSecure,
  readRefreshCookie,
  refreshCookie,
  REFRESH_COOKIE_MAX_AGE_SECONDS,
} from './web-session';

/**
 * El camino del panel. Delega en el mismo `AuthService` que el móvil; lo único
 * propio es dónde viaja el refresh token. Ver ADR-0014.
 */
@Controller('auth/web')
export class WebAuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @StrictThrottle()
  @Post('login')
  @HttpCode(200)
  @ApiOkResponse({ type: WebAuthResultDto })
  async login(
    @Body() dto: LoginDto,
    @Res({ passthrough: true }) res: Response,
  ): Promise<WebAuthResultDto> {
    return this.issue(res, await this.auth.login(dto.identifier, dto.password));
  }

  @Public()
  @StrictThrottle()
  @Post('refresh')
  @HttpCode(200)
  @ApiOkResponse({ type: WebAuthResultDto })
  async refresh(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<WebAuthResultDto> {
    const cookie = readRefreshCookie(req);
    if (!cookie) throw ApiError.unauthorized('TOKEN_INVALID', 'Sin sesión');
    return this.issue(res, await this.auth.refresh(cookie));
  }

  @Public()
  @StrictThrottle()
  @Post('logout')
  @HttpCode(204)
  @ApiNoContentResponse()
  async logout(@Req() req: Request, @Res({ passthrough: true }) res: Response): Promise<void> {
    await this.auth.logout(readRefreshCookie(req));
    res.setHeader('Set-Cookie', clearedRefreshCookie(cookieSecure()));
  }

  /** El refresh sale del cuerpo y entra a la cookie. Nunca las dos cosas. */
  private issue(res: Response, result: AuthResultDto): WebAuthResultDto {
    const { refreshToken, ...web } = result;
    res.setHeader(
      'Set-Cookie',
      refreshCookie(refreshToken, REFRESH_COOKIE_MAX_AGE_SECONDS, cookieSecure()),
    );
    return web;
  }
}
