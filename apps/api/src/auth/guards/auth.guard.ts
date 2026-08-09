import { ApiError } from '../../common/errors/api-error';
import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { IS_PUBLIC } from '../decorators/public.decorator';
import { REQUIRED_PERMISSION } from '../decorators/require-permission.decorator';
import { Permission, roleHasPermission } from '../permissions';
import { MembershipRole } from '../entities/membership.entity';
import { TenantContext } from '../../tenant/tenant-context';

export interface AccessTokenPayload {
  sub: string;
  companyId: string;
  membershipId: string;
  role: MembershipRole;
}

// Default deny: sin @Public ni @RequirePermission, el endpoint responde 403.
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const handler = context.getHandler();
    const controller = context.getClass();

    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [handler, controller])) {
      return true;
    }

    const permission = this.reflector.getAllAndOverride<Permission | undefined>(
      REQUIRED_PERMISSION,
      [handler, controller],
    );

    if (!permission) {
      throw ApiError.forbidden(
        'PERMISSION_NOT_DECLARED',
        `${controller.name}.${handler.name} no declara permiso. Usar @RequirePermission o @Public.`,
      );
    }

    const req = context.switchToHttp().getRequest<Request & { tenant?: TenantContext }>();
    const token = req.headers.authorization?.replace(/^Bearer /, '');
    if (!token) throw ApiError.unauthorized('TOKEN_MISSING', 'Falta el token');

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<AccessTokenPayload>(token);
    } catch {
      throw ApiError.unauthorized('TOKEN_INVALID', 'Token inválido o vencido');
    }

    if (!roleHasPermission(payload.role, permission)) {
      throw ApiError.forbidden('PERMISSION_DENIED', `El rol ${payload.role} no tiene ${permission}`);
    }

    req.tenant = {
      companyId: payload.companyId,
      membershipId: payload.membershipId,
      userId: payload.sub,
      role: payload.role,
    };
    return true;
  }
}
