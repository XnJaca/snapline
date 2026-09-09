import { ApiError } from '../common/errors/api-error';
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { DataSource, IsNull, Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { AppUser, Locale } from './entities/app-user.entity';
import { Membership } from './entities/membership.entity';
import { AccessTokenPayload } from './guards/auth.guard';
import { AuthResultDto, AuthMembershipDto, AuthUserDto } from './dto/auth-result.dto';
import { VerifyInviteDto } from '../memberships/dto/membership.dto';
import { TenantService } from '../tenant/tenant.service';
import { normalizeIdentifier } from './phone';
import { permissionsForRole } from './permissions';

const ACCESS_TOKEN_TTL_SECONDS = 60 * 60;

// Diez intentos por invitación. Con seis dígitos y siete días de vida, es lo que
// hace que el código no sea adivinable aunque el rate limit sea por IP.
const MAX_INVITE_ATTEMPTS = 10;

interface InviteCandidate {
  id: string;
  companyId: string;
  role: Membership['role'];
  inviteCodeHash: string;
  inviteExpiresAt: Date;
  inviteAttempts: number;
}

interface SessionMembership {
  id: string;
  companyId: string;
  companyName: string;
  role: Membership['role'];
  tokenVersion: number;
}



@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(AppUser) private readonly users: Repository<AppUser>,
    @InjectRepository(Membership) private readonly memberships: Repository<Membership>,
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly jwt: JwtService,
    private readonly tenants: TenantService,
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
    // Sin contraseña es quien fue invitado y todavía no canjeó. Se ataja antes de
    // comparar: bcrypt.compare con un nulo no devuelve false, tira TypeError.
    if (!user?.passwordHash || !(await bcrypt.compare(password, user.passwordHash))) throw invalid;

    const memberships = await this.membershipsForUser(user.id);
    if (!memberships.length) throw invalid;

    // Por defecto entra a la membresía más antigua. El criterio es explícito y
    // determinista a propósito; el cliente recibe la lista completa para ofrecer
    // cambiar de empresa. Ver DEBT-0002.
    return this.issue(user, memberships[0], memberships);
  }

  /**
   * Canjea el código que se dictó en persona. Es anterior al contexto de tenant,
   * como el login: lee con `auth_invites_for_user()` y escribe con `runAs()`.
   */
  /**
   * Comprueba el código **sin consumirlo**, para que la app pueda pedir la
   * contraseña en un segundo paso: escribirla y recién ahí enterarse de que el
   * código no servía es hacerle perder el trabajo a quien recién entra.
   *
   * Un fallo gasta intento igual que el canje. Si no, esto sería un oráculo
   * gratis para probar códigos sin límite.
   */
  async verifyInvite(identifier: string, code: string): Promise<VerifyInviteDto> {
    const { user, match } = await this.resolveInvite(identifier, code);
    // Sin contraseña en el cuerpo, `resolveInvite` o encuentra la invitación o
    // rechaza: acá `match` no puede ser nulo.
    return {
      needsPassword: user.passwordHash === null,
      expiresAt: match!.inviteExpiresAt,
    };
  }

  async redeemInvite(identifier: string, code: string, password?: string): Promise<AuthResultDto> {
    const { user, match } = await this.resolveInvite(identifier, code, password);
    if (match === null) return this.issueForRedeemed(user, password!);
    return this.activate(user, match, password);
  }

  /**
   * El camino común de verificar y canjear: resuelve la persona, su invitación
   * viva y el código, o tira el rechazo que corresponda.
   *
   * `match` nulo significa que no hay invitación pero la contraseña abre sesión:
   * es el reintento de un canje ya aplicado (regla 19), y solo lo contempla el
   * canje, no la verificación.
   */
  private async resolveInvite(
    identifier: string, code: string, password?: string,
  ): Promise<{ user: AppUser; match: InviteCandidate | null }> {
    const { email, phone } = normalizeIdentifier(identifier);
    const user = await this.users
      .createQueryBuilder('u')
      .addSelect('u.passwordHash')
      .where('u.deletedAt IS NULL')
      .andWhere(email ? 'u.email = :email' : 'u.phone = :phone', { email, phone })
      .getOne();

    const invalid = ApiError.unauthorized('INVITE_CODE_INVALID', 'Código inválido');
    if (!user) throw invalid;

    const invites = await this.invitesForUser(user.id);

    // Sin invitación viva, un reintento de un canje que ya se aplicó no puede
    // decir "código inválido" a quien acaba de elegir su contraseña (regla 19):
    // si esa contraseña resuelve sesión, se devuelve la sesión. Es un login, y
    // quien la acierta ya podía entrar por /auth/login.
    if (!invites.length) {
      if (password && user.passwordHash && (await bcrypt.compare(password, user.passwordHash))) {
        return { user, match: null };
      }
      throw invalid;
    }

    if (invites.every((i) => i.inviteAttempts >= MAX_INVITE_ATTEMPTS)) {
      throw new ApiError('INVITE_TOO_MANY_ATTEMPTS', 'Demasiados intentos: pida un código nuevo', 429);
    }

    let match: InviteCandidate | undefined;
    for (const invite of invites) {
      if (invite.inviteAttempts < MAX_INVITE_ATTEMPTS
        && (await bcrypt.compare(code, invite.inviteCodeHash))) {
        match = invite;
        break;
      }
    }

    if (!match) {
      // Se suma el intento a todas las invitaciones vivas: el servidor no sabe
      // cuál se intentaba canjear, y elegir una deja las otras sin contar, que es
      // fuerza bruta gratis para quien tenga una segunda invitación abierta.
      await this.countFailedAttempt(user.id, invites);
      throw invalid;
    }

    if (match.inviteExpiresAt.getTime() <= Date.now()) {
      throw ApiError.unauthorized('INVITE_CODE_EXPIRED', 'El código venció: pida uno nuevo');
    }

    return { user, match };
  }

  /** El reintento de un canje ya aplicado: es un login con otro nombre. */
  private async issueForRedeemed(user: AppUser, _password: string): Promise<AuthResultDto> {
    const memberships = await this.membershipsForUser(user.id);
    if (!memberships.length) {
      throw ApiError.unauthorized('INVITE_CODE_INVALID', 'Código inválido');
    }
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

    // `?? 0` y no igualdad estricta: los tokens emitidos antes de que el claim
    // existiera no lo llevan, y rechazarlos tiraría toda sesión viva en el deploy.
    if ((payload.tv ?? 0) !== membership.tokenVersion) {
      throw ApiError.unauthorized('TOKEN_INVALID', 'Sesión cerrada');
    }
    return this.issue(user, membership, memberships);
  }

  /**
   * Sube el contador de la membresía que el token nombra: todo refresh emitido
   * antes deja de servir aunque su firma siga siendo válida.
   *
   * No falla nunca. Un token ausente o ilegible es alguien que ya está afuera,
   * y no hay nada que informarle.
   */
  async logout(refreshToken: string | null): Promise<void> {
    if (!refreshToken) return;

    let payload: AccessTokenPayload & { typ?: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken);
    } catch {
      return;
    }
    if (payload.typ !== 'refresh') return;

    // La empresa sale del token ya verificado: cerrar sesión no pasa por el guard,
    // así que sin setear el contexto el UPDATE no atraviesa RLS.
    await this.tenants.runAs(
      {
        companyId: payload.companyId,
        membershipId: payload.membershipId,
        userId: payload.sub,
        role: payload.role,
      },
      () => this.memberships.increment({ id: payload.membershipId }, 'tokenVersion', 1),
    );
  }

  // Única lectura de membership fuera del scope de tenant. Ver migración AuthLookup.
  private membershipsForUser(userId: string): Promise<SessionMembership[]> {
    // ORDER BY explícito acá: Postgres no garantiza que el orden interno de una
    // función que devuelve conjunto sobreviva al SELECT externo. Ordena por id
    // porque UUIDv7 lleva el timestamp adentro, así que equivale a orden de creación.
    return this.dataSource.query<SessionMembership[]>(
      `SELECT m.id, m.company_id AS "companyId", c.name AS "companyName", m.role,
              m.token_version AS "tokenVersion"
       FROM auth_memberships_for_user($1) m
       JOIN company c ON c.id = m.company_id
       ORDER BY m.id ASC`,
      [userId],
    );
  }

  // Segunda lectura fuera del scope de tenant, y la última. Ver la migración
  // MembershipInvites y la discusión en SPEC-0011.
  private invitesForUser(userId: string): Promise<InviteCandidate[]> {
    return this.dataSource.query<InviteCandidate[]>(
      `SELECT m.id, m.company_id AS "companyId", m.role,
              m.invite_code_hash AS "inviteCodeHash",
              m.invite_expires_at AS "inviteExpiresAt",
              m.invite_attempts AS "inviteAttempts"
       FROM auth_invites_for_user($1) m
       ORDER BY m.id ASC`,
      [userId],
    );
  }

  private async countFailedAttempt(userId: string, invites: InviteCandidate[]): Promise<void> {
    for (const invite of invites) {
      await this.tenants.runAs(
        { companyId: invite.companyId, membershipId: invite.id, userId, role: invite.role },
        () => this.memberships.increment({ id: invite.id }, 'inviteAttempts', 1),
      );
    }
  }

  private async activate(user: AppUser, invite: InviteCandidate, password?: string): Promise<AuthResultDto> {
    // Quien ya trabaja para otro contratista conserva la suya: si se aceptara una
    // nueva acá, emitir un código con el teléfono de esa persona sería quedarse
    // con su cuenta, y con su acceso a la otra empresa.
    if (!user.passwordHash) {
      if (!password) {
        throw ApiError.badRequest('VALIDATION_FAILED', 'Hace falta elegir una contraseña');
      }
      await this.users.update({ id: user.id }, { passwordHash: await AuthService.hashPassword(password) });
    }

    await this.tenants.runAs(
      { companyId: invite.companyId, membershipId: invite.id, userId: user.id, role: invite.role },
      () => this.memberships.update({ id: invite.id }, {
        status: 'ACTIVE',
        joinedAt: new Date(),
        // De un solo uso: el mismo código, canjeado dos veces, ya no existe.
        inviteCodeHash: null,
        inviteExpiresAt: null,
        inviteAttempts: 0,
      }),
    );

    const fresh = await this.users.findOneOrFail({ where: { id: user.id } });
    const memberships = await this.membershipsForUser(user.id);
    const membership = memberships.find((m) => m.id === invite.id) ?? memberships[0];
    return this.issue(fresh, membership, memberships);
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
      tv: membership.tokenVersion,
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
