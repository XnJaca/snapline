import { ApiError } from '../common/errors/api-error';
import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { DataSource, IsNull, Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { AppUser, Locale } from './entities/app-user.entity';
import { Membership } from './entities/membership.entity';
import { AccessTokenPayload } from './guards/auth.guard';
import { AuthResultDto, AuthMembershipDto, AuthUserDto } from './dto/auth-result.dto';
import { normalizeIdentifier } from './phone';
import { permissionsForRole } from './permissions';

const ACCESS_TOKEN_TTL_SECONDS = 60 * 60;

interface SessionMembership {
  id: string;
  companyId: string;
  companyName: string;
  role: Membership['role'];
}



@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(AppUser) private readonly users: Repository<AppUser>,
    @InjectRepository(Membership) private readonly memberships: Repository<Membership>,
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly jwt: JwtService,
  ) {}

  async login(identifier: string, password: string): Promise<AuthResultDto> {
    const { email, phone } = normalizeIdentifier(identifier);
    const user = await this.users
      .createQueryBuilder('u')
      .addSelect('u.passwordHash')
      .where('u.deletedAt IS NULL')
      .andWhere(email ? 'u.email = :email' : 'u.phone = :phone', { email, phone })
      .getOne();

    // Mismo mensaje para usuario inexistente y contraseña mala: no revelamos cuál falló.
    const invalid = ApiError.unauthorized('INVALID_CREDENTIALS', 'Credenciales inválidas');
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) throw invalid;

    const memberships = await this.membershipsForUser(user.id);
    if (!memberships.length) throw invalid;

    // Por defecto entra a la membresía más antigua. El criterio es explícito y
    // determinista a propósito; el cliente recibe la lista completa para ofrecer
    // cambiar de empresa. Ver DEBT-0002.
    return this.issue(user, memberships[0], memberships);
  }

  async refresh(refreshToken: string): Promise<AuthResultDto> {
    let payload: AccessTokenPayload & { typ?: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken);
    } catch {
      throw ApiError.unauthorized('TOKEN_INVALID', 'Refresh token inválido o vencido');
    }
    if (payload.typ !== 'refresh') throw ApiError.unauthorized('TOKEN_INVALID', 'Token de tipo incorrecto');

    const user = await this.users.findOne({ where: { id: payload.sub } });
    const memberships = await this.membershipsForUser(payload.sub);
    const membership = memberships.find((m) => m.id === payload.membershipId);
    if (!user || !membership) throw ApiError.unauthorized('MEMBERSHIP_INACTIVE', 'Membresía inactiva');
    return this.issue(user, membership, memberships);
  }

  // Única lectura de membership fuera del scope de tenant. Ver migración AuthLookup.
  private membershipsForUser(userId: string): Promise<SessionMembership[]> {
    // ORDER BY explícito acá: Postgres no garantiza que el orden interno de una
    // función que devuelve conjunto sobreviva al SELECT externo. Ordena por id
    // porque UUIDv7 lleva el timestamp adentro, así que equivale a orden de creación.
    return this.dataSource.query<SessionMembership[]>(
      `SELECT m.id, m.company_id AS "companyId", c.name AS "companyName", m.role
       FROM auth_memberships_for_user($1) m
       JOIN company c ON c.id = m.company_id
       ORDER BY m.id ASC`,
      [userId],
    );
  }

  private async issue(
    user: AppUser,
    membership: SessionMembership,
    all: SessionMembership[],
  ): Promise<AuthResultDto> {
    const claims: AccessTokenPayload = {
      sub: user.id,
      companyId: membership.companyId,
      membershipId: membership.id,
      role: membership.role,
    };
    const toDto = (m: SessionMembership): AuthMembershipDto => ({
      id: m.id, companyId: m.companyId, companyName: m.companyName, role: m.role,
      permissions: permissionsForRole(m.role),
    });

    return {
      accessToken: await this.jwt.signAsync(claims, { expiresIn: ACCESS_TOKEN_TTL_SECONDS }),
      refreshToken: await this.jwt.signAsync({ ...claims, typ: 'refresh' }, { expiresIn: '30d' }),
      expiresInSeconds: ACCESS_TOKEN_TTL_SECONDS,
      user: {
        id: user.id, name: user.name, locale: user.locale,
        email: user.email, phone: user.phone,
      },
      membership: toDto(membership),
      memberships: all.map(toDto),
    };
  }

  /**
   * El id sale de la sesión, nunca del cuerpo: así nadie puede cambiarle el
   * idioma a otra persona.
   */
  async updateLocale(userId: string, locale: Locale): Promise<AuthUserDto> {
    const result = await this.users.update({ id: userId, deletedAt: IsNull() }, { locale });
    if (!result.affected) throw new NotFoundException('Usuario no encontrado');

    const user = await this.users.findOneOrFail({ where: { id: userId } });
    return {
      id: user.id, name: user.name, locale: user.locale,
      email: user.email, phone: user.phone,
    };
  }

  static hashPassword(plain: string): Promise<string> {
    return bcrypt.hash(plain, 12);
  }
}
